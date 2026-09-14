/// Сборка тела POST /v3/issues/_search.
///
/// Параметры `queue` / `keys` / `filter` / `query` взаимно исключают друг друга.
Map<String, dynamic>? buildIssueSearchBody({
  required String input,
  String? queuePrefix,
}) {
  final text = input.trim();
  final queue = queuePrefix?.trim() ?? '';

  // Полный ключ задачи: QUEUE-123
  if (_looksLikeIssueKey(text)) {
    return {'keys': text.toUpperCase()};
  }

  // Частичный ключ с дефисом: QUEUE-12 → язык запросов
  if (_looksLikePartialKey(text)) {
    final key = text.toUpperCase();
    if (queue.isNotEmpty) {
      return {'query': 'Queue: $queue Key: $key'};
    }
    return {'query': 'Key: $key'};
  }

  if (text.isEmpty) {
    if (queue.isEmpty) return null;
    // Пустой ввод + очередь: список задач очереди (сортировка по ключу на стороне API).
    return {'queue': queue};
  }

  // Текст / summary
  final escaped = text.replaceAll('"', r'\"');
  if (queue.isNotEmpty) {
    return {'query': 'Queue: $queue "$escaped"'};
  }
  return {'query': '"$escaped"'};
}

bool _looksLikeIssueKey(String text) {
  return RegExp(r'^[A-Za-z][A-Za-z0-9_]*-\d+$').hasMatch(text);
}

bool _looksLikePartialKey(String text) {
  return RegExp(r'^[A-Za-z][A-Za-z0-9_]*-\d*$').hasMatch(text) &&
      text.contains('-');
}
