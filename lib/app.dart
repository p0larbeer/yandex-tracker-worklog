import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/settings_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_preference.dart';
import 'core/ui/app_messenger.dart';
import 'features/browse/browse_page.dart';
import 'features/settings/settings_page.dart';
import 'features/settings/setup_page.dart';
import 'features/settings/whats_new_page.dart';
import 'features/shell/home_shell.dart';
import 'features/week/week_page.dart';

/// Корневой виджет приложения Yandex Tracker Worklog.
class YandexTrackerWorklogApp extends ConsumerWidget {
  const YandexTrackerWorklogApp({super.key});

  static const String title = 'Yandex Tracker Worklog';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final navigatorKey = ref.watch(appNavigatorKeyProvider);
    final pref =
        settingsAsync.asData?.value.themePreference ?? AppThemePreference.system;
    final themeMode = pref.material;

    return MaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      locale: const Locale('ru'),
      supportedLocales: const [
        Locale('ru'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routes: {
        HomeShell.routeName: (_) => const HomeShell(),
        WeekPage.routeName: (_) => const WeekPage(),
        BrowsePage.routeName: (_) => const BrowsePage(),
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
          return const HomeShell();
        },
      ),
    );
  }
}
