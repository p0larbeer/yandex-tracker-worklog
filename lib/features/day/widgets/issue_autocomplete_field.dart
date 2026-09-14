import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/settings_providers.dart';
import '../../../models/issue_ref.dart';
import '../../../services/tracker_api.dart';

/// Поле задачи с подсказками из Tracker `issues/_search`.
class IssueAutocompleteField extends ConsumerStatefulWidget {
  const IssueAutocompleteField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onSelected,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<IssueRef>? onSelected;

  @override
  ConsumerState<IssueAutocompleteField> createState() =>
      _IssueAutocompleteFieldState();
}

class _IssueAutocompleteFieldState
    extends ConsumerState<IssueAutocompleteField> {
  static const _perPage = 10;

  final _focusNode = FocusNode();
  final _fieldKey = GlobalKey();
  final _listScrollController = ScrollController();

  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _searchGen = 0;

  String _activeQuery = '';
  List<IssueRef> _items = const [];
  int _page = 0;
  int? _totalCount;
  bool _hasMore = false;

  @override
  void dispose() {
    _focusNode.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  double _fieldWidth() {
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final w = box?.size.width;
    if (w != null && w.isFinite && w > 0) return w;
    return 480;
  }

  Future<Iterable<IssueRef>> _search(String raw) async {
    if (!widget.enabled) return const Iterable<IssueRef>.empty();

    final settings = ref.read(settingsProvider).asData?.value;
    if (settings == null || !settings.isConfigured) {
      return const Iterable<IssueRef>.empty();
    }

    final text = raw.trim();
    final hasQueue = settings.queuePrefix.trim().isNotEmpty;
    if (text.isEmpty && !hasQueue) {
      setState(() {
        _items = const [];
        _hasMore = false;
        _totalCount = null;
        _page = 0;
        _error = null;
        _loading = false;
      });
      return const Iterable<IssueRef>.empty();
    }

    // Тот же запрос уже загружен — отдаём накопленный список (нужно для «Ещё»).
    if (text == _activeQuery && _items.isNotEmpty && !_loading) {
      return _items;
    }

    final gen = ++_searchGen;
    setState(() {
      _loading = true;
      _error = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || gen != _searchGen) {
      return const Iterable<IssueRef>.empty();
    }

    try {
      final page = await ref.read(trackerApiProvider).searchIssues(
            settings,
            input: text,
            queue: settings.queuePrefix,
            page: 1,
            perPage: _perPage,
          );
      if (!mounted || gen != _searchGen) {
        return const Iterable<IssueRef>.empty();
      }
      setState(() {
        _activeQuery = text;
        _items = page.issues;
        _page = page.page;
        _totalCount = page.totalCount;
        _hasMore = page.hasMore;
        _loading = false;
        _error = null;
      });
      return _items;
    } on TrackerApiException catch (e) {
      if (!mounted || gen != _searchGen) {
        return const Iterable<IssueRef>.empty();
      }
      setState(() {
        _items = const [];
        _hasMore = false;
        _loading = false;
        _error = e.userMessage;
      });
      return const Iterable<IssueRef>.empty();
    } catch (e) {
      if (!mounted || gen != _searchGen) {
        return const Iterable<IssueRef>.empty();
      }
      setState(() {
        _items = const [];
        _hasMore = false;
        _loading = false;
        _error = '$e';
      });
      return const Iterable<IssueRef>.empty();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    final settings = ref.read(settingsProvider).asData?.value;
    if (settings == null || !settings.isConfigured) return;

    setState(() => _loadingMore = true);
    try {
      final next = await ref.read(trackerApiProvider).searchIssues(
            settings,
            input: _activeQuery,
            queue: settings.queuePrefix,
            page: _page + 1,
            perPage: _perPage,
          );
      if (!mounted) return;
      final merged = [..._items];
      for (final issue in next.issues) {
        if (!merged.any((e) => e.id == issue.id || e.key == issue.key)) {
          merged.add(issue);
        }
      }
      setState(() {
        _items = merged;
        _page = next.page;
        _totalCount = next.totalCount ?? _totalCount;
        _hasMore = next.hasMore;
        _loadingMore = false;
      });
    } on TrackerApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _error = e.userMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _error = '$e';
      });
    }
  }

  String get _statusLabel {
    if (_items.isEmpty) return '';
    if (_totalCount != null && _totalCount! > 0) {
      return 'Показано ${_items.length} из $_totalCount';
    }
    if (_hasMore) {
      return 'Показано ${_items.length}+ (есть ещё)';
    }
    return 'Найдено: ${_items.length}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider).asData?.value;
    final queue = settings?.queuePrefix.trim() ?? '';

    return RawAutocomplete<IssueRef>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      displayStringForOption: (o) => o.key,
      optionsBuilder: (value) => _search(value.text),
      onSelected: (issue) {
        widget.controller.value = TextEditingValue(
          text: issue.key,
          selection: TextSelection.collapsed(offset: issue.key.length),
        );
        widget.onSelected?.call(issue);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // Статус списка — только в футере оверлея, иначе helper «торчит» из‑под панели.
        final helper = queue.isEmpty
            ? 'Начните вводить ключ или название задачи'
            : 'Поиск в очереди $queue (можно сменить в Настройках)';

        return TextField(
          key: _fieldKey,
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Задача *',
            hintText: queue.isEmpty
                ? 'QUEUE-123 или текст названия'
                : '$queue-… или название',
            border: const OutlineInputBorder(),
            helperText: helper,
            helperMaxLines: 2,
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.search),
            errorText: _error,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = _items.isNotEmpty ? _items : options.toList();
        if (list.isEmpty && !_hasMore) return const SizedBox.shrink();

        final width = _fieldWidth();

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: Scrollbar(
                      controller: _listScrollController,
                      thumbVisibility: true,
                      interactive: true,
                      child: ListView.separated(
                        controller: _listScrollController,
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final issue = list[index];
                          return ListTile(
                            dense: true,
                            title: Text(
                              issue.key,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: issue.display.isNotEmpty &&
                                    issue.display != issue.key
                                ? Text(
                                    issue.display,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            onTap: () => onSelected(issue),
                          );
                        },
                      ),
                    ),
                  ),
                  if (_statusLabel.isNotEmpty || _hasMore) ...[
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    Material(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_statusLabel.isNotEmpty)
                              Text(
                                _statusLabel,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (_hasMore) ...[
                              const SizedBox(height: 6),
                              FilledButton.tonalIcon(
                                onPressed: _loadingMore ? null : _loadMore,
                                icon: _loadingMore
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.expand_more),
                                label: Text(
                                  _loadingMore
                                      ? 'Загружаю…'
                                      : _totalCount != null
                                          ? 'Показать ещё (${_totalCount! - _items.length} осталось)'
                                          : 'Показать ещё',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Или уточните запрос — так быстрее найти нужную задачу',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
