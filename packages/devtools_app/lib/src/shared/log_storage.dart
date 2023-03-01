import 'dart:collection';

/// TODO Dart Doc
class LogStorage {
  static const int maxLogEntries = 3000;

  final Queue<String> _logs = Queue<String>();

  void addLog(String message) {
    _logs.add(message);
    if (_logs.length > maxLogEntries) {
      _logs.removeFirst();
    }
  }

  void clear() {
    _logs.clear();
  }

  @override
  String toString() {
    return _logs.join('\n');
  }

  // Static instance for storing the app's logs.
  static final LogStorage root = LogStorage();
}
