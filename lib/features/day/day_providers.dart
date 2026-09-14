import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_settings.dart';
import '../../core/config/settings_providers.dart';
import '../../core/utils/iso_duration.dart';
import '../../models/worklog_entry.dart';
import '../../services/tracker_api.dart';
import '../../services/worklog_service.dart';
import '../week/week_providers.dart';
import '../worklog/worklog_pending.dart';

/// Выбранный календарный день для Day View.
final selectedDayProvider = NotifierProvider<SelectedDayNotifier, DateTime>(
  SelectedDayNotifier.new,
);

class SelectedDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDay(DateTime day) {
    state = DateTime(day.year, day.month, day.day);
  }
}

final dayWorklogProvider =
    FutureProvider.autoDispose<DayViewData>((ref) async {
  ref.watch(worklogRevisionProvider);
  final pending = ref.watch(pendingWorklogsProvider);

  final settings = ref.watch(settingsProvider).asData?.value;
  if (settings == null || !settings.isConfigured) {
    throw const WeekNotConfiguredException();
  }

  final day = ref.watch(selectedDayProvider);
  final result = await ref.read(worklogServiceProvider).loadForStartRange(
    settings,
    rangeStart: day,
    rangeEnd: day,
  );

  final entries = applyPendingWorklogs(
    result.filteredByStart,
    pending,
    fromDay: day,
    toDay: day,
    timezone: settings.timezone,
  )..sort((a, b) => a.start.compareTo(b.start));

  return DayViewData(
    day: day,
    settings: settings,
    entries: entries,
    totalHours: entries.fold<double>(
      0,
      (sum, e) => sum + IsoDuration.parseToHours(e.duration),
    ),
    suggestWidenWindow:
        entries.isEmpty && result.rawFetched.isNotEmpty && pending.isEmpty,
  );
});

class DayViewData {
  const DayViewData({
    required this.day,
    required this.settings,
    required this.entries,
    required this.totalHours,
    required this.suggestWidenWindow,
  });

  final DateTime day;
  final AppSettings settings;
  final List<WorklogEntry> entries;
  final double totalHours;
  final bool suggestWidenWindow;
}

String dayErrorMessage(Object error) {
  if (error is WeekNotConfiguredException ||
      error is WorklogAuthorRequiredException) {
    return 'Сначала настройте подключение к Tracker '
        '(токен, организация и логин).';
  }
  return userFacingErrorMessage(error);
}

/// Инвалидация дня и недели (без локального pending — для кнопки «Обновить»).
void invalidateWorklogViews(WidgetRef ref) {
  ref.read(worklogRevisionProvider.notifier).bump();
}

/// Группировка записей дня по ключу задачи.
Map<String, List<WorklogEntry>> groupDayEntriesByIssue(
  List<WorklogEntry> entries,
) {
  final map = <String, List<WorklogEntry>>{};
  for (final e in entries) {
    map.putIfAbsent(e.issue.key, () => []).add(e);
  }
  return map;
}

double hoursInEntries(Iterable<WorklogEntry> entries) {
  return entries.fold<double>(
    0,
    (sum, e) => sum + IsoDuration.parseToHours(e.duration),
  );
}
