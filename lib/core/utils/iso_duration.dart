/// Конвертация ISO 8601 duration ↔ минуты/часы для UI и Yandex Tracker.
///
/// Важно: в Tracker **бизнес-сутки и недели**, не календарные:
/// 1 день (`P1D`) = 8 рабочих часов, 1 неделя (`P1W`) = 5 рабочих дней.
/// Часы/минуты после `T` (`PT8H`, `PT30M`) — обычные часы и минуты.
///
/// Иначе ответ `P1D` на списание 8 ч отображается как 24 ч.
abstract final class IsoDuration {
  /// Рабочих минут в одном бизнес-дне Tracker.
  static const int businessDayMinutes = 8 * 60;

  /// Рабочих дней в одной бизнес-неделе Tracker.
  static const int businessDaysPerWeek = 5;

  /// Парсит `PT3H`, `PT90M`, `P1D`, `P1W`, `P1DT2H` → минуты (рабочие).
  static int parseToMinutes(String raw) {
    final value = raw.trim().toUpperCase();
    if (value.isEmpty) {
      throw FormatException('Empty duration');
    }

    final weekOnly = RegExp(r'^P(\d+)W$').firstMatch(value);
    if (weekOnly != null) {
      return int.parse(weekOnly.group(1)!) *
          businessDaysPerWeek *
          businessDayMinutes;
    }

    // PnYnMnDTnHnMnS — Y/M почти не встречаются в worklog; D = бизнес-день.
    final re = RegExp(
      r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?)?$',
    );
    final m = re.firstMatch(value);
    if (m == null) {
      throw FormatException('Unsupported duration: $raw');
    }
    final years = int.parse(m.group(1) ?? '0');
    final months = int.parse(m.group(2) ?? '0');
    final days = int.parse(m.group(3) ?? '0');
    final hours = int.parse(m.group(4) ?? '0');
    final minutes = int.parse(m.group(5) ?? '0');
    final seconds = double.parse(m.group(6) ?? '0');

    // Год/месяц в Tracker worklog редки; считаем как 365/30 календарных суток
    // только чтобы не падать — для списаний обычно 0.
    final total = years * 365 * businessDayMinutes +
        months * 30 * businessDayMinutes +
        days * businessDayMinutes +
        hours * 60 +
        minutes +
        (seconds / 60).round();

    if (total <= 0 &&
        seconds == 0 &&
        years == 0 &&
        months == 0 &&
        days == 0 &&
        hours == 0 &&
        minutes == 0) {
      throw FormatException('Duration must be > 0: $raw');
    }
    return total == 0 && seconds > 0 ? 1 : total;
  }

  static double parseToHours(String raw) => parseToMinutes(raw) / 60.0;

  /// Минуты → компактный ISO для API (`PT2H30M`, `PT45M`, `PT8H`).
  ///
  /// Всегда через `T` (часы/минуты), без `PnD`/`PnW`: так Tracker не путает
  /// ввод пользователя с бизнес-днями при округлении ответа.
  static String fromMinutes(int minutes) {
    if (minutes <= 0) {
      throw ArgumentError.value(minutes, 'minutes', 'must be > 0');
    }
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return 'PT${h}H${m}M';
    if (h > 0) return 'PT${h}H';
    return 'PT${m}M';
  }

  static String fromHours(double hours) {
    final minutes = (hours * 60).round();
    return fromMinutes(minutes);
  }
}
