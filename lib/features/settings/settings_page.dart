import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/settings_providers.dart';
import 'connection_settings_form.dart';
import 'local_data_privacy_banner.dart';
import 'setup_help_panel.dart';
import 'whats_new_page.dart';

/// Экран настроек: форма подключения + справка по токену.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const String routeName = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        actions: [
          IconButton(
            tooltip: 'Что нового',
            icon: const Icon(Icons.campaign_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed(WhatsNewPage.routeName);
            },
          ),
        ],
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (settings) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 960;
              final form = ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const LocalDataPrivacyBanner(compact: true),
                  const SizedBox(height: 16),
                  ConnectionSettingsForm(initial: settings),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.campaign_outlined),
                    title: const Text('Что нового'),
                    subtitle: const Text('Версии и изменения в приложении'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).pushNamed(WhatsNewPage.routeName);
                    },
                  ),
                  if (!wide) ...[
                    const SizedBox(height: 28),
                    const Divider(),
                    const SizedBox(height: 12),
                    const SetupHelpPanel(dense: true),
                    const SizedBox(height: 12),
                    const ClientIdTokenHelper(),
                  ],
                ],
              );

              if (!wide) return form;

              return Row(
                children: [
                  Expanded(child: form),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: const [
                        SetupHelpPanel(),
                        SizedBox(height: 16),
                        ClientIdTokenHelper(),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
