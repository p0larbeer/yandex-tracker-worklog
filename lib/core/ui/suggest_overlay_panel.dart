import 'package:flutter/material.dart';

/// Единый оверлей подсказок: скролл + явный футер «есть ещё».
///
/// Используется в автокомплитах (задачи, пользователи и т.п.), чтобы поведение
/// было одинаковым: всегда видно, что список длиннее окна и/или есть догрузка.
class SuggestOverlayPanel extends StatefulWidget {
  const SuggestOverlayPanel({
    super.key,
    required this.width,
    required this.itemCount,
    required this.itemBuilder,
    this.separatorBuilder,
    this.maxListHeight = 220,
    this.statusLabel,
    this.hasMoreRemote = false,
    this.loadingMore = false,
    this.onLoadMore,
    this.loadMoreLabel,
    this.loadMoreHint,
    this.emptyChild,
  });

  final double width;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final double maxListHeight;

  /// Например: «Показано 10 из 1199» / «Найдено: 12».
  final String? statusLabel;

  /// Есть следующая страница API.
  final bool hasMoreRemote;
  final bool loadingMore;
  final VoidCallback? onLoadMore;
  final String? loadMoreLabel;
  final String? loadMoreHint;

  /// Если [itemCount] == 0.
  final Widget? emptyChild;

  @override
  State<SuggestOverlayPanel> createState() => _SuggestOverlayPanelState();
}

class _SuggestOverlayPanelState extends State<SuggestOverlayPanel> {
  final _scroll = ScrollController();
  var _overflowBelow = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateOverflow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateOverflow());
  }

  @override
  void didUpdateWidget(covariant SuggestOverlayPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateOverflow());
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_updateOverflow);
    _scroll.dispose();
    super.dispose();
  }

  void _updateOverflow() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final below =
        pos.maxScrollExtent > 8 && pos.pixels < pos.maxScrollExtent - 8;
    if (below != _overflowBelow && mounted) {
      setState(() => _overflowBelow = below);
    }
  }

  bool get _showFooter =>
      (widget.statusLabel != null && widget.statusLabel!.isNotEmpty) ||
      widget.hasMoreRemote ||
      _overflowBelow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: widget.width,
          child: widget.itemCount == 0
              ? (widget.emptyChild ?? const SizedBox.shrink())
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: widget.maxListHeight,
                      ),
                      child: Stack(
                        children: [
                          Scrollbar(
                            controller: _scroll,
                            thumbVisibility: true,
                            trackVisibility: true,
                            interactive: true,
                            child: widget.separatorBuilder != null
                                ? ListView.separated(
                                    controller: _scroll,
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: widget.itemCount,
                                    separatorBuilder: widget.separatorBuilder!,
                                    itemBuilder: widget.itemBuilder,
                                  )
                                : ListView.builder(
                                    controller: _scroll,
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: widget.itemCount,
                                    itemBuilder: widget.itemBuilder,
                                  ),
                          ),
                          if (_overflowBelow)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: IgnorePointer(
                                child: Container(
                                  height: 28,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        theme.colorScheme.surface
                                            .withValues(alpha: 0),
                                        theme.colorScheme.surface
                                            .withValues(alpha: 0.92),
                                      ],
                                    ),
                                  ),
                                  alignment: Alignment.bottomCenter,
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_showFooter) ...[
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
                              if (widget.statusLabel != null &&
                                  widget.statusLabel!.isNotEmpty)
                                Text(
                                  widget.statusLabel!,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (_overflowBelow && !widget.hasMoreRemote) ...[
                                if (widget.statusLabel != null &&
                                    widget.statusLabel!.isNotEmpty)
                                  const SizedBox(height: 4),
                                Text(
                                  'Прокрутите список — ниже есть ещё пункты',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (widget.hasMoreRemote) ...[
                                const SizedBox(height: 6),
                                FilledButton.tonalIcon(
                                  onPressed: widget.loadingMore
                                      ? null
                                      : widget.onLoadMore,
                                  icon: widget.loadingMore
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.expand_more),
                                  label: Text(
                                    widget.loadingMore
                                        ? 'Загружаю…'
                                        : (widget.loadMoreLabel ??
                                            'Показать ещё'),
                                  ),
                                ),
                                if (widget.loadMoreHint != null &&
                                    widget.loadMoreHint!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.loadMoreHint!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
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
  }
}
