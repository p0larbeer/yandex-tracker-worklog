import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/settings_providers.dart';
import 'connection_settings_form.dart';
import 'local_data_privacy_banner.dart';
import 'setup_help_panel.dart';

/// Полноэкранная настройка при первом запуске / пустых credentials.
class SetupPage extends ConsumerWidget {
  const SetupPage({super.key});

  static const String routeName = '/setup';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Не удалось загрузить настройки: $e')),
        data: (settings) {
          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 960;
                final form = ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'Yandex Tracker Worklog',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Чтобы списывать время, нужно один раз настроить доступ к API. '
                      'Справа — пошаговая инструкция; слева — поля для токена и организации.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const LocalDataPrivacyBanner(),
                    const SizedBox(height: 20),
                    const ClientIdTokenHelper(),
                    const SizedBox(height: 20),
                    ConnectionSettingsForm(
                      initial: settings,
                      isFirstRun: true,
                    ),
                    if (!wide) ...[
                      const SizedBox(height: 28),
                      const SetupHelpPanel(),
                    ],
                  ],
                );

                if (!wide) return form;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: form),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(24),
                        children: const [SetupHelpPanel()],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
