import 'package:http/http.dart' as http;

import '../../core/config/app_settings.dart';
import '../../models/worklog_entry.dart';
import 'issue_search_result.dart';
import 'tracker_http.dart';
import 'tracker_issues_api.dart';
import 'tracker_myself.dart';
import 'tracker_worklog_api.dart';

/// Фасад Tracker REST API v3 (прежний публичный API клиента).
class TrackerApiClient {
  TrackerApiClient({http.Client? httpClient})
      : _http = TrackerHttp(httpClient: httpClient) {
    worklogs = TrackerWorklogApi(_http);
    issues = TrackerIssuesApi(_http);
  }

  final TrackerHttp _http;

  late final TrackerWorklogApi worklogs;
  late final TrackerIssuesApi issues;

  static const baseUrl = TrackerHttp.baseUrl;

  Map<String, String> headers(AppSettings settings) => _http.headers(settings);

  Future<TrackerMyself> fetchMyself(AppSettings settings) async {
    final response = await _http.execute(
      _http.client.get(
        Uri.parse('${TrackerHttp.baseUrl}/myself'),
        headers: _http.headers(settings),
      ),
    );
    return _http.decodeObject(response, TrackerMyself.fromJson);
  }

  Future<List<WorklogEntry>> getWorklog(
    AppSettings settings, {
    String? createdBy,
    DateTime? createdAtFrom,
    DateTime? createdAtTo,
  }) {
    return worklogs.getWorklog(
      settings,
      createdBy: createdBy,
      createdAtFrom: createdAtFrom,
      createdAtTo: createdAtTo,
    );
  }

  Future<List<WorklogEntry>> searchWorklog(
    AppSettings settings, {
    String? createdBy,
    DateTime? createdAtFrom,
    DateTime? createdAtTo,
  }) {
    return worklogs.searchWorklog(
      settings,
      createdBy: createdBy,
      createdAtFrom: createdAtFrom,
      createdAtTo: createdAtTo,
    );
  }

  Future<List<WorklogEntry>> listIssueWorklog(
    AppSettings settings,
    String issueKey,
  ) {
    return worklogs.listIssueWorklog(settings, issueKey);
  }

  Future<WorklogEntry> createWorklog(
    AppSettings settings,
    String issueKey,
    WorklogWriteRequest request,
  ) {
    return worklogs.createWorklog(settings, issueKey, request);
  }

  Future<WorklogEntry> updateWorklog(
    AppSettings settings,
    String issueKey,
    String worklogId,
    WorklogWriteRequest request,
  ) {
    return worklogs.updateWorklog(settings, issueKey, worklogId, request);
  }

  Future<void> deleteWorklog(
    AppSettings settings,
    String issueKey,
    String worklogId,
  ) {
    return worklogs.deleteWorklog(settings, issueKey, worklogId);
  }

  Future<IssueSearchResult> searchIssues(
    AppSettings settings, {
    required String input,
    String? queue,
    int page = 1,
    int perPage = 10,
  }) {
    return issues.searchIssues(
      settings,
      input: input,
      queue: queue,
      page: page,
      perPage: perPage,
    );
  }
}
