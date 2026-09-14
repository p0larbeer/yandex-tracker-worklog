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
  });

  final WorklogEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hours = formatHours(IsoDuration.parseToHours(entry.duration));
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        title: Text(hours),
        subtitle: Text(
          entry.comment?.trim().isNotEmpty == true
              ? entry.comment!
              : 'Без комментария',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Изменить',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Удалить',
              onPressed: onDelete,
              color: theme.colorScheme.error,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}
