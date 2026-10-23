import 'package:flutter/material.dart';

/// Предпочтение темы, хранимое в настройках.
enum AppThemePreference {
  system,
  light,
  dark;

  ThemeMode get material => switch (this) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      };

  String get storageValue => name;

  static AppThemePreference fromStorage(String? raw) {
    return AppThemePreference.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AppThemePreference.system,
    );
  }

  String get labelRu => switch (this) {
        AppThemePreference.system => 'Системная',
        AppThemePreference.light => 'Светлая',
        AppThemePreference.dark => 'Тёмная',
      };
}
