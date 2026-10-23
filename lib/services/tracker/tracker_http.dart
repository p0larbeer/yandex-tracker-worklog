import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config/app_settings.dart';
import 'tracker_api_exception.dart';

/// Низкоуровневый HTTP к Tracker API: заголовки, таймаут, decode.
class TrackerHttp {
  TrackerHttp({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static const baseUrl = 'https://api.tracker.yandex.net/v3';
  static const Duration requestTimeout = Duration(seconds: 45);

  final http.Client _http;

  http.Client get client => _http;

  Map<String, String> headers(AppSettings settings) {
    final orgHeader = settings.useCloudOrgId ? 'X-Cloud-Org-ID' : 'X-Org-ID';
    return {
      'Authorization': 'OAuth ${settings.oauthToken.trim()}',
      orgHeader: settings.orgId.trim(),
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<http.Response> execute(Future<http.Response> request) async {
    try {
      return await request.timeout(requestTimeout);
    } on TimeoutException {
      throw TrackerApiException.network(
        'Превышено время ожидания ответа Tracker. '
        'Проверьте интернет и proxy (api.tracker.yandex.net).',
      );
    } on SocketException {
      throw TrackerApiException.network(
        'Нет связи с api.tracker.yandex.net. '
        'Проверьте интернет и proxy.',
      );
    } on http.ClientException catch (e) {
      throw TrackerApiException.network(
        'Сетевая ошибка при обращении к Tracker. '
        'Проверьте интернет и proxy. (${e.message})',
      );
    }
  }

  T decodeObject<T>(
    http.Response response,
    T Function(Map<String, dynamic>) fromJson, {
    Set<int> okCodes = const {200},
  }) {
    if (!okCodes.contains(response.statusCode)) {
      throw TrackerApiException(
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Expected JSON object');
    }
    return fromJson(decoded);
  }

  static int? headerInt(Map<String, String> headers, String name) {
    final raw = headers[name];
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }
}
