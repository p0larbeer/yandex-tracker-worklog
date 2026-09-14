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
    this.useRussianHolidays = true,
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

  /// Учитывать праздники РФ в статусах дней.
  final bool useRussianHolidays;

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
    bool? useRussianHolidays,
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
      useRussianHolidays: useRussianHolidays ?? this.useRussianHolidays,
    );
  }
}
