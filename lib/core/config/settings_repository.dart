import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// Загрузка/сохранение настроек: токен в secure storage, остальное в prefs.
class SettingsRepository {
  SettingsRepository({
    FlutterSecureStorage? secureStorage,
    SharedPreferences? preferences,
  }) : _secure = secureStorage ?? const FlutterSecureStorage(),
       _prefsOverride = preferences;

  static const _tokenKey = 'oauth_token';
  static const _orgIdKey = 'org_id';
  static const _useCloudOrgIdKey = 'use_cloud_org_id';
  static const _queuePrefixKey = 'queue_prefix';
  static const _loginKey = 'login';
  static const _dailyNormKey = 'daily_norm_hours';
  static const _timezoneKey = 'timezone';
  static const _weekendWeekdaysKey = 'weekend_weekdays';
  static const _useRussianHolidaysKey = 'use_russian_holidays';

  final FlutterSecureStorage _secure;
  final SharedPreferences? _prefsOverride;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _preferences() async {
    return _prefs ??= _prefsOverride ?? await SharedPreferences.getInstance();
  }

  Future<AppSettings> load() async {
    final prefs = await _preferences();
    final token = await _secure.read(key: _tokenKey) ?? '';
    return AppSettings(
      oauthToken: token,
      orgId: prefs.getString(_orgIdKey) ?? '',
      useCloudOrgId: prefs.getBool(_useCloudOrgIdKey) ?? false,
      queuePrefix: prefs.getString(_queuePrefixKey) ?? '',
      login: prefs.getString(_loginKey) ?? '',
      dailyNormHours: prefs.getDouble(_dailyNormKey) ?? 8,
      timezone: prefs.getString(_timezoneKey) ?? 'Europe/Moscow',
      weekendWeekdays: _parseWeekdays(
        prefs.getString(_weekendWeekdaysKey),
        fallback: const {DateTime.saturday, DateTime.sunday},
      ),
      useRussianHolidays: prefs.getBool(_useRussianHolidaysKey) ?? true,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await _preferences();
    await _secure.write(key: _tokenKey, value: settings.oauthToken.trim());
    await prefs.setString(_orgIdKey, settings.orgId.trim());
    await prefs.setBool(_useCloudOrgIdKey, settings.useCloudOrgId);
    await prefs.setString(_queuePrefixKey, settings.queuePrefix.trim());
    await prefs.setString(_loginKey, settings.login.trim());
    await prefs.setDouble(_dailyNormKey, settings.dailyNormHours);
    await prefs.setString(_timezoneKey, settings.timezone.trim());
    await prefs.setString(
      _weekendWeekdaysKey,
      _encodeWeekdays(settings.weekendWeekdays),
    );
    await prefs.setBool(_useRussianHolidaysKey, settings.useRussianHolidays);
  }

  Future<void> clearToken() async {
    await _secure.delete(key: _tokenKey);
  }

  static Set<int> _parseWeekdays(String? raw, {required Set<int> fallback}) {
    if (raw == null || raw.trim().isEmpty) return Set<int>.from(fallback);
    final parsed = raw
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .where((d) => d >= 1 && d <= 7)
        .toSet();
    return parsed.isEmpty ? Set<int>.from(fallback) : parsed;
  }

  static String _encodeWeekdays(Set<int> days) {
    final sorted = days.where((d) => d >= 1 && d <= 7).toList()..sort();
    return sorted.join(',');
  }
}
