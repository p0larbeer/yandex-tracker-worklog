import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/worklog_grouping.dart';
import '../../models/worklog_entry.dart';

/// Счётчик изменений worklog: week/day перечитывают API при bump.
final worklogRevisionProvider =
    NotifierProvider<WorklogRevisionNotifier, int>(WorklogRevisionNotifier.new);

class WorklogRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Локальные правки, пока Tracker `_search` может ещё не отдавать свежую запись.
final pendingWorklogsProvider =
    NotifierProvider<PendingWorklogsNotifier, PendingWorklogs>(
  PendingWorklogsNotifier.new,
);

class PendingWorklogs {
  const PendingWorklogs({
    this.upserts = const {},
    this.deletedIds = const {},
  });

  final Map<String, WorklogEntry> upserts;
  final Set<String> deletedIds;

  bool get isEmpty => upserts.isEmpty && deletedIds.isEmpty;
}

class PendingWorklogsNotifier extends Notifier<PendingWorklogs> {
  @override
  PendingWorklogs build() => const PendingWorklogs();

  void upsert(WorklogEntry entry) {
    final upserts = Map<String, WorklogEntry>.from(state.upserts)
      ..[entry.id] = entry;
    final deleted = Set<String>.from(state.deletedIds)..remove(entry.id);
    state = PendingWorklogs(upserts: upserts, deletedIds: deleted);
  }

  void remove(String id) {
    final upserts = Map<String, WorklogEntry>.from(state.upserts)..remove(id);
    final deleted = Set<String>.from(state.deletedIds)..add(id);
    state = PendingWorklogs(upserts: upserts, deletedIds: deleted);
  }
}

/// Накладывает локальные create/update/delete на ответ API.
List<WorklogEntry> applyPendingWorklogs(
  Iterable<WorklogEntry> fetched,
  PendingWorklogs pending, {
  required DateTime fromDay,
  required DateTime toDay,
  required String timezone,
}) {
  final byId = <String, WorklogEntry>{
    for (final e in fetched) e.id: e,
  };

  for (final id in pending.deletedIds) {
    byId.remove(id);
  }
  for (final entry in pending.upserts.values) {
    byId[entry.id] = entry;
  }

  return filterByStartDayRange(
    byId.values,
    fromDay: fromDay,
    toDay: toDay,
    timezone: timezone,
  );
}

/// После CRUD: локальный патч + принудительная перезагрузка списков.
void notifyWorklogChanged(
  WidgetRef ref, {
  WorklogEntry? upsert,
  String? deletedId,
}) {
  if (upsert != null) {
    ref.read(pendingWorklogsProvider.notifier).upsert(upsert);
  }
  if (deletedId != null) {
    ref.read(pendingWorklogsProvider.notifier).remove(deletedId);
  }
  ref.read(worklogRevisionProvider.notifier).bump();
}
