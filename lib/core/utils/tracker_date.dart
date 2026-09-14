/// Формат даты/времени для Tracker API: `YYYY-MM-DDThh:mm:ss.sss±hhmm`.
String formatTrackerDate(DateTime value) {
  final local = value.isUtc ? value.toLocal() : value;
  final y = local.year.toString().padLeft(4, '0');
  final mo = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final mi = local.minute.toString().padLeft(2, '0');
  final s = local.second.toString().padLeft(2, '0');
  final ms = local.millisecond.toString().padLeft(3, '0');
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final oh = offset.inHours.abs().toString().padLeft(2, '0');
  final om = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  return '$y-$mo-${d}T$h:$mi:$s.$ms$sign$oh$om';
}
