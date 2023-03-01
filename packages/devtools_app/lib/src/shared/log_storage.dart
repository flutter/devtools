import 'dart:collection';

/// TODO Dart Doc
class LogStorage {
  static const int maxLogEntries = 3000;

  final Queue<String> _logs = Queue<String>();

  void addLog(String message) {
    print('Adding Log: $message');
    _logs.add(message);
    if (_logs.length > maxLogEntries) {
      _logs.removeFirst();
    }
  }

  void clear() {
    print('Clearing Logs');
    _logs.clear();
  }

  @override
  String toString() {
    print('Logs toString ${_logs.join('\n')}');
    return _logs.join('\n');
  }

  // Static instance for storing the app's logs.
  static final LogStorage root = LogStorage();
}
