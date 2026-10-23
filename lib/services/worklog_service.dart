import '../core/config/app_settings.dart';
import '../core/utils/worklog_grouping.dart';
import '../models/worklog_entry.dart';
import 'tracker_api.dart';

/// Бизнес-логика worklog: расширенное окно createdAt + фильтр/группировка по start.
class WorklogService {
  WorklogService(this._api);

  final TrackerApiClient _api;

  /// Загрузка записей для календарного диапазона [rangeStart]…[rangeEnd]
  /// (даты работы `start`), с расширением окна поиска по `createdAt`.
  Future<WorklogRangeResult> loadForStartRange(
    AppSettings settings, {
    required DateTime rangeStart,
    required DateTime rangeEnd,
    Duration createdAtPadding = const Duration(days: 14),
    String? createdBy,
  }) async {
    final fromDay = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    final toDay = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);

    final createdFrom = fromDay.subtract(createdAtPadding);
    final createdTo = toDay
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1))
        .add(createdAtPadding);

    final author = (createdBy ?? settings.login).trim();
    if (author.isEmpty) {
      // Защита на уровне сервиса: без автора не ходим в API.
      throw const WorklogAuthorRequiredException();
    }

    final raw = await _api.searchWorklog(
      settings,
      createdBy: author,
      createdAtFrom: createdFrom,
      createdAtTo: createdTo,
    );

    final filtered = filterByStartDayRange(
      raw,
      fromDay: fromDay,
      toDay: toDay,
      timezone: settings.timezone,
    );

    final byDay = groupWorklogsByStartDay(
      filtered,
      timezone: settings.timezone,
    );

    return WorklogRangeResult(
      rawFetched: raw,
      filteredByStart: filtered,
      byDay: byDay,
      createdAtWindowFrom: createdFrom,
      createdAtWindowTo: createdTo,
      suggestWidenWindow: filtered.isEmpty && raw.isNotEmpty,
    );
  }

  Future<WorklogEntry> create(
    AppSettings settings,
    String issueKey,
    WorklogWriteRequest request,
  ) {
    return _api.createWorklog(settings, issueKey, request);
  }

  Future<WorklogEntry> update(
    AppSettings settings,
    String issueKey,
    String worklogId,
    WorklogWriteRequest request,
  ) {
    return _api.updateWorklog(settings, issueKey, worklogId, request);
  }

  Future<void> delete(
    AppSettings settings,
    String issueKey,
    String worklogId,
  ) {
    return _api.deleteWorklog(settings, issueKey, worklogId);
  }

  Future<List<WorklogEntry>> listForIssue(
    AppSettings settings,
    String issueKey,
  ) {
    return _api.listIssueWorklog(settings, issueKey);
  }
}

class WorklogRangeResult {
  const WorklogRangeResult({
    required this.rawFetched,
    required this.filteredByStart,
    required this.byDay,
    required this.createdAtWindowFrom,
    required this.createdAtWindowTo,
    required this.suggestWidenWindow,
  });

  final List<WorklogEntry> rawFetched;
  final List<WorklogEntry> filteredByStart;
  final Map<DateTime, WorklogDayBucket> byDay;
  final DateTime createdAtWindowFrom;
  final DateTime createdAtWindowTo;

  /// Записи по createdAt нашлись, но ни одна не попала в диапазон start —
  /// имеет смысл расширить окно createdAt.
  final bool suggestWidenWindow;
}

/// Нет login / createdBy — нельзя безопасно грузить worklog.
class WorklogAuthorRequiredException implements Exception {
  const WorklogAuthorRequiredException();

  @override
  String toString() => 'WorklogAuthorRequiredException';
}
