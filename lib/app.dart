import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/settings_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/ui/app_messenger.dart';
import 'features/settings/settings_page.dart';
import 'features/settings/setup_page.dart';
import 'features/settings/whats_new_page.dart';
import 'features/week/week_page.dart';

/// Корневой виджет приложения Yandex Tracker Worklog.
class YandexTrackerWorklogApp extends ConsumerWidget {
  const YandexTrackerWorklogApp({super.key});

  static const String title = 'Yandex Tracker Worklog';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final navigatorKey = ref.watch(appNavigatorKeyProvider);

    return MaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      locale: const Locale('ru'),
      theme: AppTheme.light(),
      routes: {
        WeekPage.routeName: (_) => const WeekPage(),
        SettingsPage.routeName: (_) => const SettingsPage(),
        SetupPage.routeName: (_) => const SetupPage(),
        WhatsNewPage.routeName: (_) => const WhatsNewPage(),
      },
      home: settingsAsync.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          body: Center(child: Text('Ошибка загрузки настроек: $e')),
        ),
        data: (settings) {
          if (!settings.isConfigured) {
            return const SetupPage();
          }
          return const WeekPage();
        },
      ),
    );
  }
}
