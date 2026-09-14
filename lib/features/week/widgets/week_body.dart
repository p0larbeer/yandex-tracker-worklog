import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calendar/work_calendar.dart';
import '../../day/day_page.dart';
import '../../day/day_providers.dart';
import '../week_providers.dart';
import 'week_day_row.dart';
import 'week_summary_bar.dart';

/// Список дней недели + баннеры пустого/widen состояния.
class WeekBody extends ConsumerWidget {
  const WeekBody({super.key, required this.data});

  final WeekViewData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final norm = data.settings.dailyNormHours;
    final days = weekDays(data.monday);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        WeekSummaryBar(
          weekTotal: data.weekTotalHours,
          fetched: data.result.rawFetched.length,
          shown: data.result.filteredByStart.length,
        ),
        if (data.result.filteredByStart.isEmpty) ...[
          const SizedBox(height: 8),
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                data.result.rawFetched.isEmpty
                    ? 'За эту неделю списаний нет. Откройте день и нажмите «Списание», '
                        'чтобы добавить запись.'
                    : 'Записи нашлись по дате создания, но не по дате работы (start) '
                        'в этой неделе. Попробуйте соседнюю неделю.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
        if (data.result.suggestWidenWindow) ...[
          const SizedBox(height: 8),
          Material(
            color: theme.colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'По createdAt записи нашлись, но не попали в эту неделю по дате работы (start). '
                'Попробуйте соседнюю неделю или обновите позже — окно поиска можно будет расширить.',
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (final day in days) ...[
          WeekDayRow(
            day: day,
            hours: data.hoursForDay(day),
            norm: norm,
            tasks: data.tasksSummary(day),
            kind: WorkCalendar(
              weekendWeekdays: data.settings.weekendWeekdays,
              useRussianHolidays: data.settings.useRussianHolidays,
            ).kindOf(day),
            onTap: () async {
              await DayPage.open(context, ref, day);
              invalidateWorklogViews(ref);
            },
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        Text(
          'Часы считаются по дате работы (start), не по дате создания записи. '
          'Выходные и праздники — в Настройках (дни недели + праздники РФ). '
          'Клик по дню открывает списания.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
