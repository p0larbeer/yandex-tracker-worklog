import '../theme/app_theme_preference.dart';

/// Модель пользовательских настроек приложения.
class AppSettings {
  const AppSettings({
    this.oauthToken = '',
    this.orgId = '',
    this.useCloudOrgId = false,
    this.queuePrefix = '',
    this.login = '',
    this.dailyNormHours = 8,
    this.timezone = 'Europe/Moscow',
    this.weekendWeekdays = const {DateTime.saturday, DateTime.sunday},
    this.weekStartWeekday = DateTime.monday,
    this.useRussianHolidays = true,
    this.themePreference = AppThemePreference.system,
    this.holidayTransfersUrl = '',
  });

  final String oauthToken;
  final String orgId;

  /// `true` → заголовок `X-Cloud-Org-ID`, иначе `X-Org-ID`.
  final bool useCloudOrgId;
  final String queuePrefix;
  final String login;
  final double dailyNormHours;
  final String timezone;

  /// Выходные дни недели: 1=пн … 7=вс.
  final Set<int> weekendWeekdays;

  /// Первый день недели: [DateTime.monday] или [DateTime.sunday].
  final int weekStartWeekday;

  /// Учитывать праздники РФ в статусах дней.
  final bool useRussianHolidays;

  final AppThemePreference themePreference;

  /// Opt-in URL JSON переносов (пусто = не качать, только bundled/кэш).
  final String holidayTransfersUrl;

  /// Токен + org — достаточно для `/myself` и записи настроек.
  bool get hasApiCredentials =>
      oauthToken.trim().isNotEmpty && orgId.trim().isNotEmpty;

  /// Готов к персональным worklog: credentials + login (createdBy).
  bool get isConfigured => hasApiCredentials && login.trim().isNotEmpty;

  AppSettings copyWith({
    String? oauthToken,
    String? orgId,
    bool? useCloudOrgId,
    String? queuePrefix,
    String? login,
    double? dailyNormHours,
    String? timezone,
    Set<int>? weekendWeekdays,
    int? weekStartWeekday,
    bool? useRussianHolidays,
    AppThemePreference? themePreference,
    String? holidayTransfersUrl,
  }) {
    return AppSettings(
      oauthToken: oauthToken ?? this.oauthToken,
      orgId: orgId ?? this.orgId,
      useCloudOrgId: useCloudOrgId ?? this.useCloudOrgId,
      queuePrefix: queuePrefix ?? this.queuePrefix,
      login: login ?? this.login,
      dailyNormHours: dailyNormHours ?? this.dailyNormHours,
      timezone: timezone ?? this.timezone,
      weekendWeekdays: weekendWeekdays ?? this.weekendWeekdays,
      weekStartWeekday: weekStartWeekday ?? this.weekStartWeekday,
      useRussianHolidays: useRussianHolidays ?? this.useRussianHolidays,
      themePreference: themePreference ?? this.themePreference,
      holidayTransfersUrl: holidayTransfersUrl ?? this.holidayTransfersUrl,
    );
  }
}
