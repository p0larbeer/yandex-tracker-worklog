/// Заметки релизов для экрана «Что нового» (синхронизировать с CHANGELOG.md).
class ReleaseNotes {
  const ReleaseNotes({
    required this.version,
    required this.date,
    required this.title,
    required this.highlights,
  });

  final String version;
  final String date;
  final String title;
  final List<String> highlights;
}

/// Новые сверху. При bump версии добавьте запись и обновите CHANGELOG.md.
const List<ReleaseNotes> kReleaseNotes = [
  ReleaseNotes(
    version: '0.1.0',
    date: '2026-09-14',
    title: 'Первый срез desktop worklog',
    highlights: [
      'Подключение к Yandex Tracker (токен, организация, проверка связи)',
      'Неделя и день: просмотр и CRUD списаний по дате работы',
      'Поиск задач с подсказками и «Показать ещё»',
      'Выходные и праздники РФ в статусах дней',
      'Понятные ошибки сети/API и переход в настройки при проблемах с токеном',
      'Material 3 и иконка приложения',
    ],
  ),
];
