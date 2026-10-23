import 'dart:convert';

import '../../core/config/app_settings.dart';
import 'tracker_api_exception.dart';
import 'tracker_http.dart';

/// Пользователь организации из `GET /v3/users`.
class TrackerUser {
  const TrackerUser({
    required this.uid,
    required this.display,
    this.login,
    this.email,
    this.firstName,
    this.lastName,
    this.self,
  });

  factory TrackerUser.fromJson(Map<String, dynamic> json) {
    return TrackerUser(
      uid: '${json['uid'] ?? json['trackerUid'] ?? json['id'] ?? ''}',
      display: '${json['display'] ?? json['login'] ?? json['email'] ?? ''}',
      login: json['login']?.toString(),
      email: json['email']?.toString(),
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
      self: json['self'] as String?,
    );
  }

  final String uid;
  final String display;
  final String? login;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? self;

  /// Значение для `createdBy` в worklog: логин, иначе uid.
  String get worklogAuthorId {
    final l = login?.trim();
    if (l != null && l.isNotEmpty) return l;
    return uid;
  }

  String get subtitle {
    final parts = <String>[
      if (login != null && login!.trim().isNotEmpty) login!.trim(),
      if (email != null && email!.trim().isNotEmpty) email!.trim(),
    ];
    return parts.join(' · ');
  }

  bool matches(String needleLower) {
    final hay = [
      display,
      login ?? '',
      email ?? '',
      firstName ?? '',
      lastName ?? '',
      uid,
    ].join(' ').toLowerCase();
    return hay.contains(needleLower);
  }

  /// Чем меньше — тем выше в выдаче.
  int rank(String needleLower) {
    final displayL = display.toLowerCase();
    final loginL = (login ?? '').toLowerCase();
    final emailL = (email ?? '').toLowerCase();
    final firstL = (firstName ?? '').toLowerCase();
    if (loginL == needleLower || emailL == needleLower || uid == needleLower) {
      return 0;
    }
    if (firstL.startsWith(needleLower) || displayL.startsWith(needleLower)) {
      return 1;
    }
    if (loginL.startsWith(needleLower) || emailL.startsWith(needleLower)) {
      return 2;
    }
    if (displayL.contains(needleLower) || firstL.contains(needleLower)) {
      return 3;
    }
    return 4;
  }
}

class _UsersPage {
  const _UsersPage({required this.users, required this.hasNext});

  final List<TrackerUser> users;
  final bool hasNext;
}

/// Пользователи Tracker (`/v3/users`, `/v3/users/_relative`).
class TrackerUsersApi {
  TrackerUsersApi(this._http);

  final TrackerHttp _http;

  List<TrackerUser>? _directoryCache;
  String? _directoryOrgId;

  /// Сброс кэша справочника (после смены org / токена).
  void clearDirectoryCache() {
    _directoryCache = null;
    _directoryOrgId = null;
  }

  /// Поиск по email (точный), логину/uid или подстроке ФИО по справочнику org.
  Future<List<TrackerUser>> searchUsers(
    AppSettings settings, {
    required String query,
    int limit = 25,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final byKey = <String, TrackerUser>{};

    void addAll(Iterable<TrackerUser> users) {
      for (final u in users) {
        final key = u.uid.isNotEmpty ? u.uid : u.worklogAuthorId;
        if (key.isEmpty) continue;
        byKey[key] = u;
      }
    }

    if (q.contains('@')) {
      addAll(await _listUsers(settings, email: q, perPage: 20));
      if (byKey.isNotEmpty) {
        return _sortedMatches(byKey.values, q.toLowerCase(), limit);
      }
    }

    final direct = await _getUserOrNull(settings, q);
    if (direct != null) addAll([direct]);

    // Имя / частичный логин — фильтр по полному справочнику (с кэшем на сессию).
    final directory = await _loadDirectory(settings);
    final needle = q.toLowerCase();
    addAll(directory.where((u) => u.matches(needle)));

    return _sortedMatches(byKey.values, needle, limit);
  }

  List<TrackerUser> _sortedMatches(
    Iterable<TrackerUser> users,
    String needleLower,
    int limit,
  ) {
    final list = users.toList()
      ..sort((a, b) {
        final ra = a.rank(needleLower);
        final rb = b.rank(needleLower);
        if (ra != rb) return ra.compareTo(rb);
        return a.display.toLowerCase().compareTo(b.display.toLowerCase());
      });
    if (list.length <= limit) return list;
    return list.sublist(0, limit);
  }

  Future<List<TrackerUser>> _loadDirectory(AppSettings settings) async {
    final org = settings.orgId.trim();
    if (_directoryCache != null && _directoryOrgId == org) {
      return _directoryCache!;
    }

    final all = <TrackerUser>[];
    String? afterUid;
    // До ~5000 пользователей org; обычно хватает 1–5 страниц.
    for (var page = 0; page < 50; page++) {
      final batch = await _listRelative(
        settings,
        perPage: 100,
        afterUid: afterUid,
      );
      all.addAll(batch.users);
      if (!batch.hasNext || batch.users.isEmpty) break;
      afterUid = batch.users.last.uid;
      if (afterUid.isEmpty) break;
    }

    _directoryCache = all;
    _directoryOrgId = org;
    return all;
  }

  Future<_UsersPage> _listRelative(
    AppSettings settings, {
    required int perPage,
    String? afterUid,
  }) async {
    final params = <String, String>{
      'perPage': '$perPage',
      if (afterUid != null && afterUid.isNotEmpty) 'id': afterUid,
    };
    final uri = Uri.parse('${TrackerHttp.baseUrl}/users/_relative').replace(
      queryParameters: params,
    );
    final response = await _http.execute(
      _http.client.get(uri, headers: _http.headers(settings)),
    );
    if (response.statusCode != 200) {
      // Fallback: обычный список без relative (старые права / org).
      final listed = await _listUsers(settings, perPage: perPage);
      return _UsersPage(users: listed, hasNext: false);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      // Некоторые стенды отдают массив, как у /users.
      return _UsersPage(
        users: decoded
            .map((e) => TrackerUser.fromJson(e as Map<String, dynamic>))
            .toList(),
        hasNext: decoded.length >= perPage,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Expected users/_relative object');
    }
    final raw = decoded['users'];
    final users = raw is List
        ? raw
            .map((e) => TrackerUser.fromJson(e as Map<String, dynamic>))
            .toList()
        : <TrackerUser>[];
    final hasNext = decoded['hasNext'] == true;
    return _UsersPage(users: users, hasNext: hasNext);
  }

  Future<TrackerUser?> _getUserOrNull(
    AppSettings settings,
    String idOrLogin,
  ) async {
    final key = Uri.encodeComponent(idOrLogin.trim());
    if (key.isEmpty) return null;
    try {
      final response = await _http.execute(
        _http.client.get(
          Uri.parse('${TrackerHttp.baseUrl}/users/$key'),
          headers: _http.headers(settings),
        ),
      );
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw TrackerApiException(
          statusCode: response.statusCode,
          body: response.body,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return TrackerUser.fromJson(decoded);
    } on TrackerApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<TrackerUser>> _listUsers(
    AppSettings settings, {
    String? email,
    int perPage = 100,
  }) async {
    final params = <String, String>{
      'perPage': '$perPage',
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
    };
    final uri = Uri.parse('${TrackerHttp.baseUrl}/users').replace(
      queryParameters: params,
    );
    final response = await _http.execute(
      _http.client.get(uri, headers: _http.headers(settings)),
    );
    if (response.statusCode != 200) {
      throw TrackerApiException(
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw FormatException('Expected users array');
    }
    return decoded
        .map((e) => TrackerUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
