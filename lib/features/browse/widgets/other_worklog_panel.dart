import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/settings_providers.dart';
import '../../../core/ui/api_error_pane.dart';
import '../../../core/ui/suggest_overlay_panel.dart';
import '../../../core/utils/iso_duration.dart';
import '../../../core/utils/worklog_grouping.dart';
import '../../../models/worklog_entry.dart';
import '../../../services/tracker_api.dart';
import '../../week/week_providers.dart';

/// Read-only просмотр worklog выбранного пользователя.
class OtherWorklogPanel extends ConsumerStatefulWidget {
  const OtherWorklogPanel({super.key});

  @override
  ConsumerState<OtherWorklogPanel> createState() => _OtherWorklogPanelState();
}

class _OtherWorklogPanelState extends ConsumerState<OtherWorklogPanel> {
  late final TextEditingController _query;
  late DateTime _from;
  late DateTime _to;
  bool _busy = false;
  bool _loadedOnce = false;
  Object? _error;
  List<WorklogEntry> _entries = const [];
  TrackerUser? _selected;

  @override
  void initState() {
    super.initState();
    final weekStart = ref.read(settingsProvider).asData?.value.weekStartWeekday ??
        DateTime.monday;
    _from = startOfWeek(DateTime.now(), weekStart: weekStart);
    _to = _from.add(const Duration(days: 6));
    _query = TextEditingController();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final weekStart =
        ref.read(settingsProvider).asData?.value.weekStartWeekday ??
            DateTime.monday;
    // Material: ru → week starts Monday; en_US → Sunday (picker UI only).
    final pickerLocale = weekStart == DateTime.sunday
        ? const Locale('en', 'US')
        : const Locale('ru');
    final range = await showDateRangePicker(
      context: context,
      locale: pickerLocale,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (range == null) return;
    setState(() {
      _from = DateTime(range.start.year, range.start.month, range.start.day);
      _to = DateTime(range.end.year, range.end.month, range.end.day);
    });
  }

  Future<String?> _resolveAuthorId() async {
    final selected = _selected;
    if (selected != null) return selected.worklogAuthorId;

    final text = _query.text.trim();
    if (text.isEmpty) return null;

    final settings = ref.read(settingsProvider).asData?.value;
    if (settings == null || !settings.hasApiCredentials) return null;

    final found = await ref.read(trackerApiProvider).searchUsers(
          settings,
          query: text,
        );
    if (found.isEmpty) return null;
    if (found.length > 1 && !text.contains('@')) {
      // Несколько совпадений — просим выбрать из списка, а не брать первого.
      return null;
    }
    final user = found.first;
    setState(() {
      _selected = user;
      _query.text = user.display;
    });
    return user.worklogAuthorId;
  }

  Future<void> _load() async {
    final settings = ref.read(settingsProvider).asData?.value;
    if (settings == null || !settings.hasApiCredentials) {
      setState(() => _error = 'Сначала настройте подключение');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final author = await _resolveAuthorId();
      if (author == null || author.isEmpty) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _loadedOnce = true;
          _error = _selected == null && _query.text.trim().isNotEmpty
              ? 'Выберите пользователя из списка подсказок '
                  '(по имени часто несколько совпадений).'
              : 'Не удалось найти пользователя. Введите email, логин или часть имени '
                  'и выберите из списка.';
          _entries = const [];
        });
        return;
      }
      final result = await ref.read(worklogServiceProvider).loadForStartRange(
            settings,
            rangeStart: _from,
            rangeEnd: _to,
            createdBy: author,
          );
      if (!mounted) return;
      setState(() {
        _entries = result.filteredByStart;
        _busy = false;
        _loadedOnce = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _busy = false;
        _loadedOnce = true;
        _entries = const [];
      });
    }
  }

  List<WorklogDayBucket> _bucketsFor(String timezone) {
    final map = groupWorklogsByStartDay(_entries, timezone: timezone);
    final days = map.keys.toList()..sort();
    return [for (final d in days) map[d]!];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('dd.MM.yyyy');
    final settings = ref.watch(settingsProvider).asData?.value;
    final timezone = settings?.timezone ?? 'Europe/Moscow';
    final buckets = _bucketsFor(timezone);
    final totalHours = _entries.fold<double>(
      0,
      (sum, e) => sum + IsoDuration.parseToHours(e.duration),
    );
    final selectedLabel = _selected == null
        ? null
        : [
            _selected!.display,
            if (_selected!.login != null && _selected!.login!.isNotEmpty)
              _selected!.login,
          ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Списания по пользователю (только просмотр). '
            'Ищите по email, логину или имени и выберите человека из списка.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _UserAutocompleteField(
            controller: _query,
            enabled: !_busy,
            onSelected: (user) {
              setState(() {
                _selected = user;
                _query.text = user.display;
              });
            },
            onTextChanged: () {
              if (_selected != null) {
                setState(() => _selected = null);
              }
            },
          ),
        ),
        if (selectedLabel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              'Выбран: $selectedLabel',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _busy ? null : _pickRange,
                icon: const Icon(Icons.date_range),
                label: Text('${fmt.format(_from)} — ${fmt.format(_to)}'),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : _load,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('Показать'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _error != null
              ? ApiErrorPane(
                  message: _error is TrackerApiException
                      ? (_error as TrackerApiException).userMessage
                      : '$_error',
                  onRetry: _load,
                )
              : !_loadedOnce && _entries.isEmpty
                  ? Center(
                      child: Text(
                        _busy ? 'Загрузка…' : 'Выберите пользователя и период',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : _entries.isEmpty
                      ? Center(
                          child: Text(
                            _busy ? 'Загрузка…' : 'Нет записей за период',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                          children: [
                            Material(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'Итого: ${formatHours(totalHours)} · '
                                  'дней: ${buckets.length} · '
                                  'записей: ${_entries.length}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            for (final bucket in buckets) ...[
                              _DaySection(
                                day: bucket.day,
                                hours: bucket.totalHours,
                                entries: bucket.entries,
                              ),
                              const SizedBox(height: 14),
                            ],
                          ],
                        ),
        ),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.hours,
    required this.entries,
  });

  final DateTime day;
  final double hours;
  final List<WorklogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = entries.length;
    final countLabel = switch (n) {
      1 => '1 запись',
      >= 2 && <= 4 => '$n записи',
      _ => '$n записей',
    };

    return Material(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.65),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatDayTitle(day),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          countLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatHours(hours),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            _OtherWorklogRow(entry: entries[i]),
          ],
        ],
      ),
    );
  }
}

class _OtherWorklogRow extends StatelessWidget {
  const _OtherWorklogRow({required this.entry});

  final WorklogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = IsoDuration.parseToHours(entry.duration);
    final comment = (entry.comment ?? '').trim();
    final summary = entry.issue.display.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.issue.key,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  SelectableText(
                    comment,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatHours(h),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserAutocompleteField extends ConsumerStatefulWidget {
  const _UserAutocompleteField({
    required this.controller,
    required this.enabled,
    required this.onSelected,
    required this.onTextChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<TrackerUser> onSelected;
  final VoidCallback onTextChanged;

  @override
  ConsumerState<_UserAutocompleteField> createState() =>
      _UserAutocompleteFieldState();
}

class _UserAutocompleteFieldState
    extends ConsumerState<_UserAutocompleteField> {
  final _focusNode = FocusNode();
  final _fieldKey = GlobalKey();
  int _gen = 0;
  bool _searching = false;
  List<TrackerUser> _items = const [];

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  double _fieldWidth() {
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final w = box?.size.width;
    if (w != null && w.isFinite && w > 0) return w;
    return 520;
  }

  Future<Iterable<TrackerUser>> _search(String raw) async {
    if (!widget.enabled) return const Iterable<TrackerUser>.empty();
    final settings = ref.read(settingsProvider).asData?.value;
    if (settings == null || !settings.hasApiCredentials) {
      return const Iterable<TrackerUser>.empty();
    }
    final text = raw.trim();
    if (text.length < 2) {
      setState(() => _items = const []);
      return const Iterable<TrackerUser>.empty();
    }

    final gen = ++_gen;
    setState(() => _searching = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || gen != _gen) return const Iterable<TrackerUser>.empty();

    try {
      final users = await ref.read(trackerApiProvider).searchUsers(
            settings,
            query: text,
          );
      if (!mounted || gen != _gen) return const Iterable<TrackerUser>.empty();
      setState(() {
        _searching = false;
        _items = users;
      });
      return users;
    } catch (_) {
      if (mounted && gen == _gen) {
        setState(() {
          _searching = false;
          _items = const [];
        });
      }
      return const Iterable<TrackerUser>.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<TrackerUser>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) => _search(value.text),
      displayStringForOption: (u) => u.display,
      onSelected: widget.onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          key: _fieldKey,
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: 'Пользователь (email, логин или имя)',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person_search),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          onChanged: (_) => widget.onTextChanged(),
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = _items.isNotEmpty ? _items : options.toList();
        return SuggestOverlayPanel(
          width: _fieldWidth(),
          itemCount: list.length,
          maxListHeight: 240,
          statusLabel: list.isEmpty
              ? null
              : 'Найдено: ${list.length}'
                  '${list.length >= 25 ? ' (показаны первые)' : ''}',
          emptyChild: ListTile(
            title: Text(_searching ? 'Ищем…' : 'Никого не найдено'),
          ),
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final u = list[i];
            return ListTile(
              title: Text(u.display),
              subtitle: Text(
                u.subtitle.isEmpty ? u.uid : u.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onSelected(u),
            );
          },
        );
      },
    );
  }
}
