import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_settings.dart';
import '../../core/config/settings_providers.dart';
import '../../core/utils/iso_duration.dart';
import '../../core/utils/worklog_grouping.dart';
import '../../models/worklog_entry.dart';
import '../../services/tracker_api.dart';
import '../../services/worklog_service.dart';
import '../worklog/worklog_pending.dart';

/// Понедельник текущей (или выбранной) недели — локальный календарный день.
class WeekAnchorNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => startOfWeek(DateTime.now());

  void setMonday(DateTime monday) {
    state = DateTime(monday.year, monday.month, monday.day);
  }

  void shiftWeeks(int delta) {
    state = state.add(Duration(days: 7 * delta));
  }

  void goToToday() {
    state = startOfWeek(DateTime.now());
  }
}

final weekAnchorProvider =
    NotifierProvider<WeekAnchorNotifier, DateTime>(WeekAnchorNotifier.new);

DateTime startOfWeek(DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  // DateTime.weekday: Mon=1 … Sun=7
  return d.subtract(Duration(days: d.weekday - 1));
}

List<DateTime> weekDays(DateTime monday) {
  return List.generate(7, (i) => monday.add(Duration(days: i)));
}

final weekWorklogProvider =
    FutureProvider.autoDispose<WeekViewData>((ref) async {
  ref.watch(worklogRevisionProvider);
  final pending = ref.watch(pendingWorklogsProvider);

  final settingsAsync = ref.watch(settingsProvider);
  final settings = settingsAsync.asData?.value;
  if (settings == null || !settings.isConfigured) {
    throw const WeekNotConfiguredException();
  }

  final monday = ref.watch(weekAnchorProvider);
  final sunday = monday.add(const Duration(days: 6));
  final result = await ref.read(worklogServiceProvider).loadForStartRange(
    settings,
    rangeStart: monday,
    rangeEnd: sunday,
  );

  final filtered = applyPendingWorklogs(
    result.filteredByStart,
    pending,
    fromDay: monday,
    toDay: sunday,
    timezone: settings.timezone,
  );
  final byDay = groupWorklogsByStartDay(
    filtered,
    timezone: settings.timezone,
  );

  return WeekViewData(
    settings: settings,
    monday: monday,
    sunday: sunday,
    result: WorklogRangeResult(
      rawFetched: result.rawFetched,
      filteredByStart: filtered,
      byDay: byDay,
      createdAtWindowFrom: result.createdAtWindowFrom,
      createdAtWindowTo: result.createdAtWindowTo,
      suggestWidenWindow: filtered.isEmpty && result.rawFetched.isNotEmpty,
    ),
  );
});

class WeekNotConfiguredException implements Exception {
  const WeekNotConfiguredException();
}

class WeekViewData {
  const WeekViewData({
    required this.settings,
    required this.monday,
    required this.sunday,
    required this.result,
  });

  final AppSettings settings;
  final DateTime monday;
  final DateTime sunday;
  final WorklogRangeResult result;

  double get weekTotalHours {
    var sum = 0.0;
    for (final day in weekDays(monday)) {
      sum += hoursForDay(day);
    }
    return sum;
  }

  double hoursForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return result.byDay[key]?.totalHours ?? 0;
  }

  List<WorklogEntry> entriesForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return result.byDay[key]?.entries ?? const [];
  }

  /// Компактная сводка задач за день: KEY (часы).
  String tasksSummary(DateTime day) {
    final entries = entriesForDay(day);
    if (entries.isEmpty) return '—';
    final byKey = <String, double>{};
    for (final e in entries) {
      byKey[e.issue.key] =
          (byKey[e.issue.key] ?? 0) + IsoDuration.parseToHours(e.duration);
    }
    return byKey.entries
        .map((e) => '${e.key} (${_fmtHours(e.value)})')
        .join(', ');
  }
}

String formatWeekRange(DateTime monday, DateTime sunday) {
  try {
    final fmt = DateFormat('d MMM', 'ru');
    final y = DateFormat('y', 'ru');
    if (monday.year == sunday.year) {
      return '${fmt.format(monday)} – ${fmt.format(sunday)} ${y.format(sunday)}';
    }
    return '${fmt.format(monday)} ${y.format(monday)} – ${fmt.format(sunday)} ${y.format(sunday)}';
  } catch (_) {
    return '${monday.day}.${monday.month}.${monday.year} – '
        '${sunday.day}.${sunday.month}.${sunday.year}';
  }
}

String formatDayLabel(DateTime day) {
  const weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
  final wd = weekdays[day.weekday - 1];
  final dd = day.day.toString().padLeft(2, '0');
  final mm = day.month.toString().padLeft(2, '0');
  return '$wd $dd.$mm';
}

/// Заголовок экрана дня: полная дата (неделя остаётся короткой).
String formatDayTitle(DateTime day) {
  try {
    return DateFormat('EEEE, d MMMM y', 'ru').format(day);
  } catch (_) {
    const weekdays = [
      'понедельник',
      'вторник',
      'среда',
      'четверг',
      'пятница',
      'суббота',
      'воскресенье',
    ];
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    return '${weekdays[day.weekday - 1]}, ${day.day} ${months[day.month - 1]} ${day.year}';
  }
}

String _fmtHours(double hours) {
  if (hours == hours.roundToDouble()) return '${hours.toInt()} ч';
  return '${hours.toStringAsFixed(1)} ч';
}

String formatHours(double hours) => _fmtHours(hours);

/// Для отображения ошибок API на экране недели.
String weekErrorMessage(Object error) {
  if (error is WeekNotConfiguredException ||
      error is WorklogAuthorRequiredException) {
    return 'Сначала настройте подключение к Tracker '
        '(токен, организация и логин).';
  }
  return userFacingErrorMessage(error);
}
