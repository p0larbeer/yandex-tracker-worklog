import 'package:flutter/material.dart';

import '../../../core/calendar/work_calendar.dart';
import '../../../core/theme/app_theme.dart';
import '../week_providers.dart';

/// Строка дня на неделе: часы, статус нормы, сводка задач.
class WeekDayRow extends StatelessWidget {
  const WeekDayRow({
    super.key,
    required this.day,
    required this.hours,
    required this.norm,
    required this.tasks,
    required this.kind,
    required this.onTap,
  });

  final DateTime day;
  final double hours;
  final double norm;
  final String tasks;
  final DayKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = DayStatus.resolve(kind: kind, hours: hours, norm: norm);
    final semantic = AppSemanticColors.of(context);

    final Color statusColor = switch (status.tone) {
      DayStatusTone.muted => theme.colorScheme.outline,
      DayStatusTone.success => semantic.success,
      DayStatusTone.overtime => semantic.warning,
      DayStatusTone.empty => theme.colorScheme.error,
      DayStatusTone.warning => semantic.warning,
    };

    return Material(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatDayLabel(day),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    formatHours(hours),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                tasks,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
