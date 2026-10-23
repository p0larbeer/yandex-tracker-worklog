import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_settings.dart';
import 'error_log.dart';

/// Текстовый отчёт для пользователя (без токена / org / login).
Future<String> buildSupportReport({AppSettings? settings}) async {
  final info = await PackageInfo.fromPlatform();
  final buf = StringBuffer()
    ..writeln('Yandex Tracker Worklog — support report')
    ..writeln('generated: ${DateTime.now().toIso8601String()}')
    ..writeln()
    ..writeln('app: ${info.appName} ${info.version}+${info.buildNumber}')
    ..writeln('package: ${info.packageName}')
    ..writeln('platform: ${kIsWeb ? 'web' : Platform.operatingSystem} '
        '${kIsWeb ? '' : Platform.operatingSystemVersion}')
    ..writeln('locale: ${Platform.localeName}');

  if (settings != null) {
    buf
      ..writeln()
      ..writeln('settings (no secrets):')
      ..writeln('  hasApiCredentials: ${settings.hasApiCredentials}')
      ..writeln('  isConfigured: ${settings.isConfigured}')
      ..writeln('  useCloudOrgId: ${settings.useCloudOrgId}')
      ..writeln('  dailyNormHours: ${settings.dailyNormHours}')
      ..writeln('  timezone: ${settings.timezone}')
      ..writeln('  weekStartWeekday: ${settings.weekStartWeekday}')
      ..writeln('  weekendWeekdays: ${settings.weekendWeekdays.toList()..sort()}')
      ..writeln('  useRussianHolidays: ${settings.useRussianHolidays}')
      ..writeln('  theme: ${settings.themePreference.storageValue}')
      ..writeln(
        '  holidayTransfersUrlSet: '
        '${settings.holidayTransfersUrl.trim().isNotEmpty}',
      );
  }

  final errors = AppErrorLog.entries;
  buf
    ..writeln()
    ..writeln('recent errors (${errors.length}):');
  if (errors.isEmpty) {
    buf.writeln('  (none)');
  } else {
    for (final e in errors) {
      for (final line in e.split('\n')) {
        buf.writeln('  $line');
      }
    }
  }

  return buf.toString();
}
