import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/settings_providers.dart';
import '../../../core/ui/api_error_pane.dart';
import '../../../models/issue_ref.dart';
import '../../../services/tracker_api.dart';

class _IssuePreset {
  const _IssuePreset({
    required this.id,
    required this.label,
    required this.query,
  });

  final String id;
  final String label;
  final String Function(String queuePrefix) query;
}

enum _IssueSort {
  updatedDesc,
  updatedAsc,
  createdDesc,
  createdAsc,
  statusAsc,
  keyAsc,
}

extension on _IssueSort {
  String get label => switch (this) {
        _IssueSort.updatedDesc => 'Обновление ↓',
        _IssueSort.updatedAsc => 'Обновление ↑',
        _IssueSort.createdDesc => 'Создание ↓',
        _IssueSort.createdAsc => 'Создание ↑',
        _IssueSort.statusAsc => 'Статус',
        _IssueSort.keyAsc => 'Ключ',
      };

  String get queryClause => switch (this) {
        _IssueSort.updatedDesc => 'Updated DESC',
        _IssueSort.updatedAsc => 'Updated ASC',
        _IssueSort.createdDesc => 'Created DESC',
        _IssueSort.createdAsc => 'Created ASC',
        _IssueSort.statusAsc => 'Status ASC',
        _IssueSort.keyAsc => 'Key ASC',
      };
}

class _StatusOption {
  const _StatusOption({required this.key, required this.display});

  final String key;
  final String display;

  @override
  bool operator ==(Object other) =>
      other is _StatusOption && other.key == key && other.display == display;

  @override
  int get hashCode => Object.hash(key, display);
}

/// Пресеты «мои задачи / баги» (query Tracker).
class MyIssuesPanel extends ConsumerStatefulWidget {
  const MyIssuesPanel({super.key});

  @override
  ConsumerState<MyIssuesPanel> createState() => _MyIssuesPanelState();
}

class _MyIssuesPanelState extends ConsumerState<MyIssuesPanel> {
  static const _perPage = 20;

  static final _presets = <_IssuePreset>[
    _IssuePreset(
      id: 'mine_open',
      label: 'На мне (открытые)',
      query: (q) {
        final queue = q.trim().isEmpty ? '' : 'Queue: $q ';
        return '${queue}Assignee: me() Resolution: empty()';
      },
    ),
    _IssuePreset(
      id: 'mine_bugs',
      label: 'Мои баги',
      query: (q) {
        final queue = q.trim().isEmpty ? '' : 'Queue: $q ';
        return '${queue}Assignee: me() Type: bug Resolution: empty()';
      },
    ),
    _IssuePreset(
      id: 'queue_open',
      label: 'Очередь (открытые)',
      query: (q) {
        if (q.trim().isEmpty) {
          return 'Assignee: me() Resolution: empty()';
        }
        return 'Queue: $q Resolution: empty()';
      },
    ),
  ];

  late String _presetId;
  _IssueSort _sort = _IssueSort.updatedDesc;
  _StatusOption? _statusFilter;
  final Set<_StatusOption> _knownStatuses = {};

  bool _busy = false;
  bool _autoLoadStarted = false;
  Object? _error;
  List<IssueRef> _issues = const [];
  int _page = 1;
  int? _totalPages;
  int? _totalCount;

  @override
  void initState() {
    super.initState();
    _presetId = _presets.first.id;
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoLoad());
  }

  void _tryAutoLoad() {
    if (_autoLoadStarted || !mounted) return;
    final settings = ref.read(settingsProvider).asData?.value;
    if (settings == null || !settings.hasApiCredentials) return;
    _autoLoadStarted = true;
    _load(page: 1);
  }

  String _buildQuery(String queuePrefix) {
    final preset = _presets.firstWhere((p) => p.id == _presetId);
    final parts = <String>[preset.query(queuePrefix)];
    final statusDisplay = _statusFilter?.display.trim();
    if (statusDisplay != null && statusDisplay.isNotEmpty) {
      parts.add('"Status": "$statusDisplay"');
    }
    parts.add('"Sort by": ${_sort.queryClause}');
    return parts.join(' ');
  }

  Future<void> _load({required int page}) async {
    final settings = ref.read(settingsProvider).asData?.value;
    if (settings == null || !settings.hasApiCredentials) {
      setState(() => _error = 'Сначала настройте подключение');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _page = page;
    });
    try {
      final result = await ref.read(trackerApiProvider).searchIssuesByQuery(
            settings,
            query: _buildQuery(settings.queuePrefix),
            page: page,
            perPage: _perPage,
          );
      if (!mounted) return;
      for (final issue in result.issues) {
        final display = issue.statusDisplay?.trim();
        if (display == null || display.isEmpty) continue;
        _knownStatuses.add(
          _StatusOption(
            key: issue.statusKey?.trim().isNotEmpty == true
                ? issue.statusKey!.trim()
                : display,
            display: display,
          ),
        );
      }
      setState(() {
        _issues = result.issues;
        _totalPages = result.totalPages;
        _totalCount = result.totalCount;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _busy = false;
        _issues = const [];
        _totalPages = null;
        _totalCount = null;
      });
    }
  }

  Future<void> _openIssue(IssueRef issue) async {
    final key = issue.key.trim();
    if (key.isEmpty) return;
    final uri = Uri.parse('https://tracker.yandex.ru/$key');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _onPresetChanged(String? value) {
    if (value == null || value == _presetId) return;
    setState(() {
      _presetId = value;
      _statusFilter = null;
      _knownStatuses.clear();
    });
    _load(page: 1);
  }

  void _onSortChanged(_IssueSort? value) {
    if (value == null || value == _sort) return;
    setState(() => _sort = value);
    _load(page: 1);
  }

  void _onStatusChanged(_StatusOption? value) {
    setState(() => _statusFilter = value);
    _load(page: 1);
  }

  bool get _canPrev => !_busy && _page > 1;

  bool get _canNext {
    if (_busy) return false;
    if (_totalPages != null && _totalPages! > 0) return _page < _totalPages!;
    return _issues.length >= _perPage;
  }

  String get _pageLabel {
    final total = _totalPages;
    if (total != null && total > 0) return 'Стр. $_page / $total';
    return 'Стр. $_page';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat('dd.MM.yy');
    final statusItems = _knownStatuses.toList()
      ..sort((a, b) => a.display.compareTo(b.display));
    if (_statusFilter != null && !statusItems.contains(_statusFilter)) {
      statusItems.insert(0, _statusFilter!);
    }

    ref.listen(settingsProvider, (prev, next) {
      if (!_autoLoadStarted && next.hasValue) _tryAutoLoad();
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Пресеты Tracker. Загрузка при открытии; очередь — из настроек, '
            'если задана.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _presetId,
            decoration: const InputDecoration(
              labelText: 'Пресет',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final p in _presets)
                DropdownMenuItem(value: p.id, child: Text(p.label)),
            ],
            onChanged: _busy ? null : _onPresetChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<_IssueSort>(
                  // ignore: deprecated_member_use
                  value: _sort,
                  decoration: const InputDecoration(
                    labelText: 'Сортировка',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final s in _IssueSort.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: _busy ? null : _onSortChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<_StatusOption?>(
                  // ignore: deprecated_member_use
                  value: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Статус',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<_StatusOption?>(
                      value: null,
                      child: Text('Все'),
                    ),
                    for (final s in statusItems)
                      DropdownMenuItem(value: s, child: Text(s.display)),
                  ],
                  onChanged: _busy ? null : _onStatusChanged,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : () => _load(page: 1),
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Обновить'),
              ),
              if (_totalCount != null) ...[
                const SizedBox(width: 12),
                Text(
                  'Всего: $_totalCount',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
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
                  onRetry: () => _load(page: _page),
                )
              : _issues.isEmpty
                  ? Center(
                      child: Text(
                        _busy ? 'Загрузка…' : 'Нет задач по пресету',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _issues.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final issue = _issues[i];
                        final updated = issue.updatedAt;
                        final status = issue.statusDisplay?.trim();
                        final subtitleParts = <String>[
                          if (status != null && status.isNotEmpty) status,
                          if (updated != null)
                            'обн. ${dateFmt.format(updated.toLocal())}',
                          issue.display,
                        ];
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          title: Text(issue.key),
                          subtitle: Text(
                            subtitleParts.join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.open_in_new, size: 18),
                          onTap: () => _openIssue(issue),
                        );
                      },
                    ),
        ),
        if (_issues.isNotEmpty || _page > 1) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                TextButton(
                  onPressed: _canPrev ? () => _load(page: _page - 1) : null,
                  child: const Text('Назад'),
                ),
                Expanded(
                  child: Text(
                    _pageLabel,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: _canNext ? () => _load(page: _page + 1) : null,
                  child: const Text('Далее'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
