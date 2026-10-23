/// Ошибки Tracker HTTP / сети и тексты для UI.
class TrackerApiException implements Exception {
  TrackerApiException({
    required this.statusCode,
    required this.body,
    this.networkMessage,
  });

  factory TrackerApiException.network(String message) {
    return TrackerApiException(
      statusCode: 0,
      body: message,
      networkMessage: message,
    );
  }

  final int statusCode;
  final String body;

  /// Заполняется для сетевых ошибок (не HTTP-статус Tracker).
  final String? networkMessage;

  bool get isNetwork => statusCode == 0 || networkMessage != null;

  bool get isUnauthorized => statusCode == 401;

  /// Стоит предложить открыть настройки (токен / org).
  bool get suggestsOpenSettings =>
      isUnauthorized || statusCode == 403 || statusCode == 404;

  String get userMessage {
    if (networkMessage != null) return networkMessage!;
    switch (statusCode) {
      case 401:
        return 'Токен неверный или просрочен (401). '
            'Откройте Настройки и создайте новый OAuth-токен.';
      case 403:
        return 'Нет прав на API (403). Проверьте разрешения '
            'tracker:read / tracker:write.';
      case 404:
        return 'Объект или организация не найдены (404). Проверьте ID / ключ '
            'задачи и тип заголовка (X-Org-ID или X-Cloud-Org-ID).';
      case 429:
        return 'Слишком много запросов (429). Подождите и повторите.';
      default:
        if (statusCode >= 500) {
          return 'Сервер Tracker временно недоступен ($statusCode). '
              'Попробуйте позже.';
        }
        return 'Ошибка Tracker API ($statusCode).';
    }
  }

  @override
  String toString() => 'TrackerApiException($statusCode): $body';
}

/// Единый текст ошибки для UI (неделя, день, messenger).
String userFacingErrorMessage(Object error) {
  if (error is TrackerApiException) return error.userMessage;
  final text = '$error';
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup')) {
    return 'Нет связи с api.tracker.yandex.net. Проверьте интернет и proxy.';
  }
  return 'Не удалось выполнить запрос: $error';
}

bool errorSuggestsOpenSettings(Object error) {
  return error is TrackerApiException && error.suggestsOpenSettings;
}
