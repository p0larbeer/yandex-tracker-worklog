import 'dart:convert';

import '../../core/config/app_settings.dart';
import '../../core/utils/issue_search_query.dart';
import '../../models/issue_ref.dart';
import 'issue_search_result.dart';
import 'tracker_api_exception.dart';
import 'tracker_http.dart';

/// Поиск задач Tracker (`issues/_search`).
class TrackerIssuesApi {
  TrackerIssuesApi(this._http);

  final TrackerHttp _http;

  /// POST /v3/issues/_search
  Future<IssueSearchResult> searchIssues(
    AppSettings settings, {
    required String input,
    String? queue,
    int page = 1,
    int perPage = 10,
  }) async {
    final body = buildIssueSearchBody(
      input: input,
      queuePrefix: queue ?? settings.queuePrefix,
    );
    if (body == null) {
      return IssueSearchResult.empty(page: page, perPage: perPage);
    }

    final uri = Uri.parse('${TrackerHttp.baseUrl}/issues/_search').replace(
      queryParameters: {
        'perPage': '$perPage',
        'page': '$page',
      },
    );
    final response = await _http.execute(
      _http.client.post(
        uri,
        headers: _http.headers(settings),
        body: jsonEncode(body),
      ),
    );
    if (response.statusCode != 200) {
      throw TrackerApiException(
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw FormatException('Expected issues array');
    }
    final issues = decoded
        .map((e) => IssueRef.fromJson(e as Map<String, dynamic>))
        .toList();
    return IssueSearchResult(
      issues: issues,
      page: page,
      perPage: perPage,
      totalCount: TrackerHttp.headerInt(response.headers, 'x-total-count'),
      totalPages: TrackerHttp.headerInt(response.headers, 'x-total-pages'),
    );
  }
}
