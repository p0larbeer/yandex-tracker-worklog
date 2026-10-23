import '../../models/worklog_entry.dart';
import 'iso_duration.dart';

/// Группировка worklog по календарной дате поля `start` в заданной timezone.

class WorklogDayBucket {
  const WorklogDayBucket({
    required this.day,
    required this.entries,
  });

  /// Календарный день (локальная дата без времени, в зоне [timezone]).
  final DateTime day;
  final List<WorklogEntry> entries;

  int get totalMinutes => entries.fold<int>(
    0,
    (sum, e) => sum + IsoDuration.parseToMinutes(e.duration),
  );

  double get totalHours => totalMinutes / 60.0;
}

/// Ключ дня YYYY-MM-DD в [timezoneName] (IANA, напр. Europe/Moscow).
///
/// Без пакета timezone используем фиксированный offset для известных зон
/// MVP: Europe/Moscow = UTC+3; иначе — локальная зона устройства.
DateTime calendarDayForStart(DateTime start, {String timezone = 'Europe/Moscow'}) {
  final shifted = _toZone(start, timezone);
  return DateTime(shifted.year, shifted.month, shifted.day);
}

Map<DateTime, WorklogDayBucket> groupWorklogsByStartDay(
  Iterable<WorklogEntry> entries, {
  String timezone = 'Europe/Moscow',
}) {
  final map = <DateTime, List<WorklogEntry>>{};
  for (final entry in entries) {
    final day = calendarDayForStart(entry.start, timezone: timezone);
    map.putIfAbsent(day, () => []).add(entry);
  }
  final result = <DateTime, WorklogDayBucket>{};
  for (final e in map.entries) {
    final list = List<WorklogEntry>.from(e.value)
      ..sort((a, b) => a.start.compareTo(b.start));
    result[e.key] = WorklogDayBucket(day: e.key, entries: list);
  }
  return result;
}

/// Фильтр: `start` попадает в [fromDay, toDay] включительно (календарные дни).
List<WorklogEntry> filterByStartDayRange(
  Iterable<WorklogEntry> entries, {
  required DateTime fromDay,
  required DateTime toDay,
  String timezone = 'Europe/Moscow',
}) {
  final from = DateTime(fromDay.year, fromDay.month, fromDay.day);
  final to = DateTime(toDay.year, toDay.month, toDay.day);
  return entries.where((e) {
    final day = calendarDayForStart(e.start, timezone: timezone);
    return !day.isBefore(from) && !day.isAfter(to);
  }).toList();
}

DateTime _toZone(DateTime value, String timezone) {
  final utc = value.toUtc();
  switch (timezone) {
    case 'Europe/Moscow':
      return utc.add(const Duration(hours: 3));
    case 'UTC':
      return utc;
    default:
      // Fallback: локаль устройства
      return value.toLocal();
  }
}
