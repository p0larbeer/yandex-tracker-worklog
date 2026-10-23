import 'package:flutter/material.dart';

import '../../../core/utils/iso_duration.dart';
import '../../../models/worklog_entry.dart';
import '../../week/week_providers.dart';

/// Плитка одной записи worklog в дне.
class WorklogTile extends StatelessWidget {
  const WorklogTile({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
    this.embedded = false,
  });

  final WorklogEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Внутри карточки группы задачи — без своей рамки.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hours = formatHours(IsoDuration.parseToHours(entry.duration));
    final comment = entry.comment?.trim();
    final hasComment = comment != null && comment.isNotEmpty;

    final row = Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SizedBox(
              width: 56,
              child: Text(
                hours,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, right: 4),
              child: SelectableText(
                hasComment ? comment : 'Без комментария',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: hasComment
                      ? null
                      : theme.colorScheme.onSurfaceVariant,
                  fontStyle: hasComment ? null : FontStyle.italic,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Изменить',
            onPressed: onEdit,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Удалить',
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
            color: theme.colorScheme.error,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );

    if (embedded) return row;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: row,
    );
  }
}
