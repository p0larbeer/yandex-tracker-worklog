import 'iso_duration.dart';

/// Ввод длительности пользователем (как в Jira), не ISO для API.
///
/// Примеры: `1.5`, `1,5`, `30m`, `1h`, `1h 30m`, `1d` (= 8 ч), `1w` (= 40 ч).
/// Русские единицы: `1ч 30м`, `1д`, `45мин`.
abstract final class HumanDuration {
  static const int dayMinutes = IsoDuration.businessDayMinutes;
  static const int weekMinutes =
      IsoDuration.businessDaysPerWeek * IsoDuration.businessDayMinutes;

  /// Парсит ввод → минуты. Бросает [FormatException], если строка невалидна.
  static int parseToMinutes(String raw) {
    final s = raw.trim().toLowerCase().replaceAll(',', '.');
    if (s.isEmpty) {
      throw const FormatException('Пустая длительность');
    }

    // Число без единиц = часы (как раньше в форме).
    if (RegExp(r'^\d+(\.\d+)?$').hasMatch(s)) {
      final hours = double.parse(s);
      if (hours <= 0) {
        throw FormatException('Длительность должна быть > 0: $raw');
      }
      final minutes = (hours * 60).round();
      if (minutes <= 0) {
        throw FormatException('Длительность должна быть > 0: $raw');
      }
      return minutes;
    }

    final tokenRe = RegExp(
      r'(\d+(?:\.\d+)?)\s*'
      r'(недел(?:я|и|ь)?|недель|нед|н|w|'
      r'дней|день|дня|дн|д|d|'
      r'часов|часа|час|ч|h|'
      r'минут|минуты|минута|мин|м|m)',
      caseSensitive: false,
    );

    final matches = tokenRe.allMatches(s).toList();
    if (matches.isEmpty) {
      throw FormatException('Не понял длительность: $raw');
    }

    var cursor = 0;
    var total = 0;
    for (final m in matches) {
      final gap = s.substring(cursor, m.start).trim();
      if (gap.isNotEmpty) {
        throw FormatException('Не понял длительность: $raw');
      }
      cursor = m.end;

      final amount = double.parse(m.group(1)!);
      if (amount < 0) {
        throw FormatException('Длительность должна быть > 0: $raw');
      }
      final unit = m.group(2)!.toLowerCase();
      total += _toMinutes(amount, unit);
    }

    if (s.substring(cursor).trim().isNotEmpty) {
      throw FormatException('Не понял длительность: $raw');
    }
    if (total <= 0) {
      throw FormatException('Длительность должна быть > 0: $raw');
    }
    return total;
  }

  static double parseToHours(String raw) => parseToMinutes(raw) / 60.0;

  /// `null`, если ввод пустой или невалидный (для live-подсказки).
  static int? tryParseToMinutes(String raw) {
    try {
      if (raw.trim().isEmpty) return null;
      return parseToMinutes(raw);
    } on FormatException {
      return null;
    }
  }

  /// Компактный ввод для поля формы: `1h`, `30m`, `1h 30m`.
  static String formatCompact(int minutes) {
    if (minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  /// Человекочитаемо по-русски: `1 ч 30 мин`.
  static String formatRu(int minutes) {
    if (minutes <= 0) return '0 мин';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '$h ч $m мин';
    if (h > 0) return '$h ч';
    return '$m мин';
  }

  static const String inputHint = '1h 30m';
  static const String inputExamples =
      'Примеры: 1.5 · 30m · 1h 30m · 1d (=8 ч)';

  static int _toMinutes(double amount, String unit) {
    if (unit == 'w' ||
        unit == 'н' ||
        unit == 'нед' ||
        unit.startsWith('недел') ||
        unit == 'недель') {
      return (amount * weekMinutes).round();
    }
    if (unit == 'd' ||
        unit == 'д' ||
        unit == 'дн' ||
        unit == 'день' ||
        unit == 'дня' ||
        unit == 'дней') {
      return (amount * dayMinutes).round();
    }
    if (unit == 'h' ||
        unit == 'ч' ||
        unit == 'час' ||
        unit == 'часа' ||
        unit == 'часов') {
      return (amount * 60).round();
    }
    // m / м / мин…
    return (amount).round();
  }
}
