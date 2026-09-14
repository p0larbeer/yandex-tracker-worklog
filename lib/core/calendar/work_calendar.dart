/// Тип календарного дня для статусов недели/дня.
enum DayKind {
  workday,
  weekend,
  holiday,
}

extension DayKindX on DayKind {
  bool get isNonWorking => this != DayKind.workday;

  String get shortLabel => switch (this) {
        DayKind.workday => 'рабочий',
        DayKind.weekend => 'выходной',
        DayKind.holiday => 'праздник',
      };
}

/// Календарь рабочих/нерабочих дней (выходные недели + праздники РФ).
class WorkCalendar {
  const WorkCalendar({
    this.weekendWeekdays = defaultWeekendWeekdays,
    this.useRussianHolidays = true,
  });

  /// По умолчанию суббота и воскресенье (`DateTime.weekday`: 6, 7).
  static const Set<int> defaultWeekendWeekdays = {DateTime.saturday, DateTime.sunday};

  /// Дни недели, считающиеся выходными (1=пн … 7=вс).
  final Set<int> weekendWeekdays;

  /// Учитывать нерабочие праздничные дни РФ (+ известные переносы).
  final bool useRussianHolidays;

  DayKind kindOf(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (useRussianHolidays && isRussianHoliday(d)) {
      return DayKind.holiday;
    }
    if (weekendWeekdays.contains(d.weekday)) {
      return DayKind.weekend;
    }
    return DayKind.workday;
  }

  bool isNonWorking(DateTime day) => kindOf(day).isNonWorking;

  /// Официальные праздники ст. 112 ТК РФ + переносы для известных лет.
  static bool isRussianHoliday(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return russianHolidayDates(d.year).contains(d);
  }

  static Set<DateTime> russianHolidayDates(int year) {
    final base = <DateTime>{
      for (var day = 1; day <= 8; day++) DateTime(year, 1, day),
      DateTime(year, 2, 23),
      DateTime(year, 3, 8),
      DateTime(year, 5, 1),
      DateTime(year, 5, 9),
      DateTime(year, 6, 12),
      DateTime(year, 11, 4),
    };
    final extras = _transferAndBridgeDays[year];
    if (extras != null) {
      for (final e in extras) {
        base.add(DateTime(year, e.$1, e.$2));
      }
    }
    return base;
  }

  /// Доп. нерабочие дни (переносы / мосты) по производственному календарю.
  /// Годы без записи — только базовые праздники ст. 112.
  /// Значения: пары (месяц, день).
  static const Map<int, Set<(int, int)>> _transferAndBridgeDays = {
    2025: {
      (1, 9),
      (5, 2),
      (11, 3),
      (12, 31),
    },
    2026: {
      // ПП РФ от 24.09.2025 № 1466: 3 янв → 9 янв, 4 янв → 31 дек.
      (1, 9),
      (3, 9),
      (5, 11),
      (6, 13),
      (6, 14),
      (12, 31),
    },
    2027: {
      (1, 9),
      (2, 22),
      (5, 10),
      (11, 5),
      (12, 31),
    },
  };
}

/// Семантика бейджа для темы (без сравнения русских строк в UI).
enum DayStatusTone {
  /// Выходной / праздник — нейтральный outline.
  muted,

  /// Норма часов ровно закрыта (в допуске).
  success,

  /// Больше дневной нормы.
  overtime,

  /// Рабочий день без списаний.
  empty,

  /// Часы есть, но меньше нормы.
  warning,
}

/// Статус бейджа дня: календарь + фактически списанные часы.
class DayStatus {
  const DayStatus({
    required this.kind,
    required this.label,
    required this.tone,
  });

  final DayKind kind;
  final String label;
  final DayStatusTone tone;

  /// Нужен ли акцент нормы (не muted).
  bool get emphasizeNorm => tone != DayStatusTone.muted;

  factory DayStatus.resolve({
    required DayKind kind,
    required double hours,
    required double norm,
  }) {
    if (kind.isNonWorking) {
      if (hours == 0) {
        return DayStatus(
          kind: kind,
          label: kind == DayKind.holiday ? 'праздник' : 'выходной',
          tone: DayStatusTone.muted,
        );
      }
      return DayStatus(
        kind: kind,
        label: kind == DayKind.holiday ? 'праздник' : 'нерабочий',
        tone: DayStatusTone.muted,
      );
    }
    if (hours == 0) {
      return const DayStatus(
        kind: DayKind.workday,
        label: 'пусто',
        tone: DayStatusTone.empty,
      );
    }
    if (hours > norm + 0.01) {
      final over = hours - norm;
      final overLabel = over == over.roundToDouble()
          ? '+${over.toInt()} ч'
          : '+${over.toStringAsFixed(1)} ч';
      return DayStatus(
        kind: DayKind.workday,
        label: 'сверхнорма $overLabel',
        tone: DayStatusTone.overtime,
      );
    }
    if (hours >= norm - 0.01) {
      return const DayStatus(
        kind: DayKind.workday,
        label: 'норма',
        tone: DayStatusTone.success,
      );
    }
    final remaining = norm - hours;
    final rem = remaining == remaining.roundToDouble()
        ? '${remaining.toInt()} ч'
        : '${remaining.toStringAsFixed(1)} ч';
    return DayStatus(
      kind: DayKind.workday,
      label: 'ещё $rem',
      tone: DayStatusTone.warning,
    );
  }
}
