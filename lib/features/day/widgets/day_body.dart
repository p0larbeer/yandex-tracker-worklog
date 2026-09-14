import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calendar/work_calendar.dart';
import '../../../core/config/settings_providers.dart';
import '../../../core/ui/app_messenger.dart';
import '../../../core/utils/iso_duration.dart';
import '../../../models/worklog_entry.dart';
import '../../../services/tracker_api.dart';
import '../../week/week_providers.dart';
import '../../worklog/worklog_pending.dart';
import '../day_providers.dart';
import '../log_form_page.dart';
import 'worklog_tile.dart';

/// Список списаний дня + итог / empty / widen.
class DayBody extends ConsumerWidget {
  const DayBody({super.key, required this.data});

  final DayViewData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final grouped = groupDayEntriesByIssue(data.entries);
    final norm = data.settings.dailyNormHours;
    final remaining = norm - data.totalHours;
    final kind = WorkCalendar(
      weekendWeekdays: data.settings.weekendWeekdays,
      useRussianHolidays: data.settings.useRussianHolidays,
    ).kindOf(data.day);
    final String caption;
    if (data.totalHours > norm + 0.01) {
      final over = data.totalHours - norm;
      caption = kind.isNonWorking
          ? 'Сверх нормы: ${formatHours(over)} (${kind.shortLabel} день)'
          : 'Сверх нормы: ${formatHours(over)}';
    } else if (data.totalHours >= norm - 0.01) {
      caption = kind.isNonWorking
          ? 'Норма закрыта (${kind.shortLabel} день)'
          : 'Норма закрыта';
    } else if (kind.isNonWorking) {
      caption = data.totalHours == 0
          ? 'Нерабочий день (${kind.shortLabel}) — норма не требуется'
          : 'Нерабочий день (${kind.shortLabel}), списано '
              '${formatHours(data.totalHours)}';
    } else {
      caption = 'До нормы: ${formatHours(remaining)}';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      children: [
        Material(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Итого: ${formatHours(data.totalHours)} '
                  '(норма ${formatHours(norm)})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(caption, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
        if (data.suggestWidenWindow) ...[
          const SizedBox(height: 8),
          Material(
            color: theme.colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Есть записи по createdAt вне окна start. '
                'Если чего-то не хватает — сообщите, расширим поиск.',
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (data.entries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Center(
              child: Text(
                'За этот день списаний нет.\nНажмите «Списание», чтобы добавить.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          for (final entry in grouped.entries) ...[
            Text(
              '${entry.key} · ${formatHours(hoursInEntries(entry.value))}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (entry.value.first.issue.display.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  entry.value.first.issue.display,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final item in entry.value)
              WorklogTile(
                entry: item,
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LogFormPage(
                        day: data.day,
                        existing: item,
                      ),
                    ),
                  );
                },
                onDelete: () => _confirmDelete(context, ref, item),
              ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    WorklogEntry entry,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: Text(
          '${entry.issue.key}: ${formatHours(IsoDuration.parseToHours(entry.duration))}'
          '${entry.comment != null && entry.comment!.isNotEmpty ? '\n${entry.comment}' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final messenger = ref.read(appMessengerProvider);
    final settings = ref.read(settingsProvider).asData?.value;
    if (settings == null) return;
    try {
      await ref.read(worklogServiceProvider).delete(
            settings,
            entry.issue.key,
            entry.id,
          );
      notifyWorklogChanged(ref, deletedId: entry.id);
      messenger.success('Запись удалена');
    } on TrackerApiException catch (e) {
      messenger.fromError(e);
    } catch (e) {
      messenger.fromError(e);
    }
  }
}
