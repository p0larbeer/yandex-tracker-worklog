/// Ring-buffer последних ошибок для support-отчёта (без секретов).
abstract final class AppErrorLog {
  static const int _max = 40;
  static final List<String> _entries = [];

  static List<String> get entries => List.unmodifiable(_entries);

  static void record(Object error, [StackTrace? stack]) {
    final ts = DateTime.now().toIso8601String();
    final msg = '$ts  $error';
    _entries.add(msg);
    if (stack != null) {
      final lines = stack.toString().split('\n').take(8).join('\n');
      if (lines.isNotEmpty) {
        _entries.add(lines);
      }
    }
    while (_entries.length > _max) {
      _entries.removeAt(0);
    }
  }

  static void clear() => _entries.clear();
}
