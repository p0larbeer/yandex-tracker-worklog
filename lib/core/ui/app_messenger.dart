import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/tracker_api.dart';
import '../theme/app_theme.dart';

enum AppMessageKind { info, success, error }

/// Глобальные уведомления: компактный toast **сверху по центру**.
///
/// Низ экрана (список, FAB) не перекрывается — в отличие от SnackBar.
class AppMessenger {
  AppMessenger(this._navigatorKey);

  final GlobalKey<NavigatorState> _navigatorKey;

  OverlayEntry? _entry;
  Timer? _timer;

  OverlayState? get _overlay => _navigatorKey.currentState?.overlay;

  void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }

  void show(
    String message, {
    AppMessageKind kind = AppMessageKind.info,
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = _overlay;
    final navContext = _navigatorKey.currentContext;
    if (overlay == null || navContext == null || !navContext.mounted) return;

    final theme = Theme.of(navContext);
    final scheme = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>();

    final Color background;
    final Color foreground;
    switch (kind) {
      case AppMessageKind.info:
        background = scheme.inverseSurface;
        foreground = scheme.onInverseSurface;
      case AppMessageKind.success:
        background = semantic?.success ?? scheme.primary;
        foreground = semantic?.onSuccess ?? scheme.onPrimary;
      case AppMessageKind.error:
        background = scheme.error;
        foreground = scheme.onError;
    }

    hide();

    final entry = OverlayEntry(
      builder: (ctx) {
        // Под AppBar: низ (список + FAB) свободен.
        final top =
            MediaQuery.paddingOf(ctx).top + kToolbarHeight + 8;
        return Positioned(
          top: top,
          left: 16,
          right: 16,
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: _TopToast(
                message: message,
                kind: kind,
                background: background,
                foreground: foreground,
                textStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: foreground,
                ),
              ),
            ),
          ),
        );
      },
    );

    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(duration, hide);
  }

  void info(String message) => show(message, kind: AppMessageKind.info);

  void success(String message) =>
      show(message, kind: AppMessageKind.success);

  void error(String message) =>
      show(message, kind: AppMessageKind.error, duration: const Duration(seconds: 4));

  void fromError(Object error) {
    this.error(userFacingErrorMessage(error));
  }
}

class _TopToast extends StatefulWidget {
  const _TopToast({
    required this.message,
    required this.kind,
    required this.background,
    required this.foreground,
    required this.textStyle,
  });

  final String message;
  final AppMessageKind kind;
  final Color background;
  final Color foreground;
  final TextStyle? textStyle;

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..forward();

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -0.35),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Material(
            color: widget.background,
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    switch (widget.kind) {
                      AppMessageKind.info => Icons.info_outline,
                      AppMessageKind.success => Icons.check_circle_outline,
                      AppMessageKind.error => Icons.error_outline,
                    },
                    color: widget.foreground,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: widget.textStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final appNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) {
  return GlobalKey<NavigatorState>();
});

final appMessengerProvider = Provider<AppMessenger>((ref) {
  final messenger = AppMessenger(ref.watch(appNavigatorKeyProvider));
  ref.onDispose(messenger.hide);
  return messenger;
});
