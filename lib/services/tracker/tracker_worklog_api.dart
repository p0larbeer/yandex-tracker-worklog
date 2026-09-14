import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_settings.dart';
import '../../core/utils/tracker_date.dart';
import '../../models/worklog_entry.dart';
import 'tracker_api_exception.dart';
import 'tracker_http.dart';

/// Эндпоинты worklog Tracker API.
class TrackerWorklogApi {
  TrackerWorklogApi(this._http);

  final TrackerHttp _http;

  /// GET /v3/worklog?createdBy=&createdAt=from:&createdAt=to:
  Future<List<WorklogEntry>> getWorklog(
    AppSettings settings, {
    String? createdBy,
    DateTime? createdAtFrom,
    DateTime? createdAtTo,
  }) async {
    final parts = <String>[];
    if (createdBy != null && createdBy.trim().isNotEmpty) {
      parts.add('createdBy=${Uri.encodeQueryComponent(createdBy.trim())}');
    }
    if (createdAtFrom != null) {
      parts.add(
        'createdAt=${Uri.encodeQueryComponent('from:${formatTrackerDate(createdAtFrom)}')}',
      );
    }
    if (createdAtTo != null) {
      parts.add(
        'createdAt=${Uri.encodeQueryComponent('to:${formatTrackerDate(createdAtTo)}')}',
      );
    }
    final uri = Uri.parse(
      parts.isEmpty
          ? '${TrackerHttp.baseUrl}/worklog'
          : '${TrackerHttp.baseUrl}/worklog?${parts.join('&')}',
    );
    final response = await _http.execute(
      _http.client.get(uri, headers: _http.headers(settings)),
    );
    return _decodeList(response);
  }

  /// POST /v3/worklog/_search
  Future<List<WorklogEntry>> searchWorklog(
    AppSettings settings, {
    String? createdBy,
    DateTime? createdAtFrom,
    DateTime? createdAtTo,
  }) async {
    final body = <String, dynamic>{};
    if (createdBy != null && createdBy.trim().isNotEmpty) {
      body['createdBy'] = createdBy.trim();
    }
    if (createdAtFrom != null || createdAtTo != null) {
      body['createdAt'] = {
        if (createdAtFrom != null) 'from': formatTrackerDate(createdAtFrom),
        if (createdAtTo != null) 'to': formatTrackerDate(createdAtTo),
      };
    }
    final response = await _http.execute(
      _http.client.post(
        Uri.parse('${TrackerHttp.baseUrl}/worklog/_search'),
        headers: _http.headers(settings),
        body: jsonEncode(body),
      ),
    );
    return _decodeList(response);
  }

  /// GET /v3/issues/{key}/worklog
  Future<List<WorklogEntry>> listIssueWorklog(
    AppSettings settings,
    String issueKey,
  ) async {
    final key = Uri.encodeComponent(issueKey.trim());
    final response = await _http.execute(
      _http.client.get(
        Uri.parse('${TrackerHttp.baseUrl}/issues/$key/worklog'),
        headers: _http.headers(settings),
      ),
    );
    return _decodeList(response);
  }

  /// POST /v3/issues/{key}/worklog
  Future<WorklogEntry> createWorklog(
    AppSettings settings,
    String issueKey,
    WorklogWriteRequest request,
  ) async {
    final key = Uri.encodeComponent(issueKey.trim());
    final response = await _http.execute(
      _http.client.post(
        Uri.parse('${TrackerHttp.baseUrl}/issues/$key/worklog'),
        headers: _http.headers(settings),
        body: jsonEncode(request.toJson()),
      ),
    );
    return _http.decodeObject(
      response,
      WorklogEntry.fromJson,
      okCodes: {201, 200},
    );
  }

  /// PATCH /v3/issues/{key}/worklog/{id}
  Future<WorklogEntry> updateWorklog(
    AppSettings settings,
    String issueKey,
    String worklogId,
    WorklogWriteRequest request,
  ) async {
    final key = Uri.encodeComponent(issueKey.trim());
    final id = Uri.encodeComponent(worklogId.trim());
    final response = await _http.execute(
      _http.client.patch(
        Uri.parse('${TrackerHttp.baseUrl}/issues/$key/worklog/$id'),
        headers: _http.headers(settings),
        body: jsonEncode(request.toJson()),
      ),
    );
    return _http.decodeObject(response, WorklogEntry.fromJson);
  }

  /// DELETE /v3/issues/{key}/worklog/{id}
  Future<void> deleteWorklog(
    AppSettings settings,
    String issueKey,
    String worklogId,
  ) async {
    final key = Uri.encodeComponent(issueKey.trim());
    final id = Uri.encodeComponent(worklogId.trim());
    final response = await _http.execute(
      _http.client.delete(
        Uri.parse('${TrackerHttp.baseUrl}/issues/$key/worklog/$id'),
        headers: _http.headers(settings),
      ),
    );
    if (response.statusCode == 204 || response.statusCode == 200) return;
    throw TrackerApiException(
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  List<WorklogEntry> _decodeList(http.Response response) {
    if (response.statusCode != 200) {
      throw TrackerApiException(
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    return WorklogEntry.listFromJson(jsonDecode(response.body));
  }
}
