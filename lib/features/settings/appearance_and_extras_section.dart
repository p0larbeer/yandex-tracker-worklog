import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_settings.dart';
import '../../core/config/settings_providers.dart';
import '../../core/diagnostics/support_report.dart';
import '../../core/platform/linux_desktop_integration.dart';
import '../../core/theme/app_theme_preference.dart';
import '../../core/ui/app_messenger.dart';

/// Тема, календарь (URL), AppImage → меню.
class AppearanceAndExtrasSection extends ConsumerStatefulWidget {
  const AppearanceAndExtrasSection({super.key, required this.initial});

  final AppSettings initial;

  @override
  ConsumerState<AppearanceAndExtrasSection> createState() =>
      _AppearanceAndExtrasSectionState();
}

class _AppearanceAndExtrasSectionState
    extends ConsumerState<AppearanceAndExtrasSection> {
  late AppThemePreference _theme;
  late final TextEditingController _holidayUrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _theme = widget.initial.themePreference;
    _holidayUrl =
        TextEditingController(text: widget.initial.holidayTransfersUrl);
  }

  @override
  void dispose() {
    _holidayUrl.dispose();
    super.dispose();
  }

  Future<void> _saveTheme(AppThemePreference value) async {
    setState(() => _theme = value);
    final current =
        ref.read(settingsProvider).asData?.value ?? widget.initial;
    await ref.read(settingsProvider.notifier).save(
          current.copyWith(themePreference: value),
        );
  }

  Future<void> _saveHolidayUrl() async {
    setState(() => _busy = true);
    try {
      final next = (ref.read(settingsProvider).asData?.value ?? widget.initial)
          .copyWith(holidayTransfersUrl: _holidayUrl.text.trim());
      await ref.read(settingsProvider.notifier).save(next);
      await ref
          .read(holidayTransfersProvider.notifier)
          .refreshFromConfiguredUrl();
      if (!mounted) return;
      ref.read(appMessengerProvider).success('Календарь переносов обновлён');
    } catch (e) {
      if (!mounted) return;
      ref.read(appMessengerProvider).error('Не удалось обновить календарь: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _installDesktop() async {
    setState(() => _busy = true);
    try {
      final path = await LinuxDesktopIntegration.install(
        appName: 'Yandex Tracker Worklog',
        desktopId: 'yandex_tracker_worklog',
      );
      if (!mounted) return;
      ref.read(appMessengerProvider).success('Ярлык создан: $path');
    } catch (e) {
      if (!mounted) return;
      ref.read(appMessengerProvider).error('Не удалось добавить в меню: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copySupportReport() async {
    setState(() => _busy = true);
    try {
      final settings =
          ref.read(settingsProvider).asData?.value ?? widget.initial;
      final text = await buildSupportReport(settings: settings);
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ref.read(appMessengerProvider).success('Отчёт скопирован в буфер обмена');
    } catch (e) {
      if (!mounted) return;
      ref.read(appMessengerProvider).error('Не удалось собрать отчёт: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings =
        ref.watch(settingsProvider).asData?.value ?? widget.initial;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Оформление',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<AppThemePreference>(
          segments: [
            for (final p in AppThemePreference.values)
              ButtonSegment(value: p, label: Text(p.labelRu)),
          ],
          selected: {_theme},
          onSelectionChanged: _busy
              ? null
              : (s) {
                  if (s.isEmpty) return;
                  _saveTheme(s.first);
                },
        ),
        const SizedBox(height: 24),
        Text(
          'Праздники (переносы)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'По умолчанию — файл в приложении. URL заполняйте только если нужен '
          'live-обновление без новой сборки (opt-in).',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _holidayUrl,
          decoration: const InputDecoration(
            labelText: 'URL JSON переносов (необязательно)',
            hintText:
                'https://raw.githubusercontent.com/.../holiday_transfers.json',
            border: OutlineInputBorder(),
          ),
          enabled: !_busy,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: _busy ? null : _saveHolidayUrl,
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(
              settings.holidayTransfersUrl.trim().isEmpty &&
                      _holidayUrl.text.trim().isEmpty
                  ? 'Сохранить и перечитать локальный календарь'
                  : 'Сохранить URL и обновить',
            ),
          ),
        ),
        if (LinuxDesktopIntegration.isSupported) ...[
          const SizedBox(height: 24),
          Text(
            'Linux',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: _busy ? null : _installDesktop,
              icon: const Icon(Icons.install_desktop_outlined),
              label: const Text('Добавить в меню приложений'),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Диагностика',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Версия, ОС и последние ошибки без токена и логина — '
          'можно вставить в Issue / чат.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: _busy ? null : _copySupportReport,
            icon: const Icon(Icons.bug_report_outlined),
            label: const Text('Скопировать отчёт о сбое'),
          ),
        ),
      ],
    );
  }
}
