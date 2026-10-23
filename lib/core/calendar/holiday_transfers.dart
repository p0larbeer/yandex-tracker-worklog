import 'dart:convert';

/// Переносы / мосты производственного календаря (месяц, день) по годам.
class HolidayTransfers {
  const HolidayTransfers({
    required this.byYear,
    this.updated,
  });

  final Map<int, Set<(int, int)>> byYear;
  final String? updated;

  static const HolidayTransfers baked = HolidayTransfers(
    byYear: {
      2025: {
        (1, 9),
        (5, 2),
        (11, 3),
        (12, 31),
      },
      2026: {
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
    },
    updated: 'baked',
  );

  static const HolidayTransfers empty = HolidayTransfers(byYear: {});

  /// [other] перекрывает дни этого экземпляра по годам (полная замена года).
  HolidayTransfers mergeYearsFrom(HolidayTransfers other) {
    if (other.byYear.isEmpty) return this;
    final merged = Map<int, Set<(int, int)>>.from(byYear);
    for (final e in other.byYear.entries) {
      merged[e.key] = Set<(int, int)>.from(e.value);
    }
    return HolidayTransfers(
      byYear: merged,
      updated: other.updated ?? updated,
    );
  }

  factory HolidayTransfers.fromJson(Map<String, dynamic> json) {
    final yearsRaw = json['years'];
    final byYear = <int, Set<(int, int)>>{};
    if (yearsRaw is Map) {
      for (final e in yearsRaw.entries) {
        final year = int.tryParse(e.key.toString());
        if (year == null) continue;
        final days = <(int, int)>{};
        final list = e.value;
        if (list is! List) continue;
        for (final item in list) {
          if (item is List && item.length >= 2) {
            final m = int.tryParse(item[0].toString());
            final d = int.tryParse(item[1].toString());
            if (m != null && d != null) days.add((m, d));
          }
        }
        if (days.isNotEmpty) byYear[year] = days;
      }
    }
    return HolidayTransfers(
      byYear: byYear,
      updated: json['updated']?.toString(),
    );
  }

  factory HolidayTransfers.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('holiday transfers: expected object');
    }
    return HolidayTransfers.fromJson(decoded);
  }

  Map<String, dynamic> toJson() => {
        if (updated != null) 'updated': updated,
        'years': {
          for (final e in byYear.entries)
            '${e.key}': [
              for (final d in e.value) [d.$1, d.$2],
            ],
        },
      };
}
