import 'package:flutter/material.dart';

/// Общий экран/блок ошибки API: повторить и/или открыть настройки.
class ApiErrorPane extends StatelessWidget {
  const ApiErrorPane({
    super.key,
    required this.message,
    required this.onRetry,
    this.onSettings,
    this.emphasizeSettings = false,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onSettings;
  final bool emphasizeSettings;

  @override
  Widget build(BuildContext context) {
    final showSettings = onSettings != null;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                emphasizeSettings ? Icons.lock_outline : Icons.error_outline,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              if (showSettings && emphasizeSettings) ...[
                FilledButton.icon(
                  onPressed: onSettings,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Открыть настройки'),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: onRetry, child: const Text('Повторить')),
              ] else if (showSettings) ...[
                FilledButton(onPressed: onRetry, child: const Text('Повторить')),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onSettings,
                  child: const Text('Открыть настройки'),
                ),
              ] else
                FilledButton(onPressed: onRetry, child: const Text('Повторить')),
            ],
          ),
        ),
      ),
    );
  }
}
