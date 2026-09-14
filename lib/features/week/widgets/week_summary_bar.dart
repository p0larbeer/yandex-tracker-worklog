import 'package:flutter/material.dart';

import '../week_providers.dart';

/// Итого часов и счётчики записей за неделю.
class WeekSummaryBar extends StatelessWidget {
  const WeekSummaryBar({
    super.key,
    required this.weekTotal,
    required this.fetched,
    required this.shown,
  });

  final double weekTotal;
  final int fetched;
  final int shown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.timelapse, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Итого за неделю: ${formatHours(weekTotal)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Записей в диапазоне start: $shown (загружено по createdAt: $fetched)',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
