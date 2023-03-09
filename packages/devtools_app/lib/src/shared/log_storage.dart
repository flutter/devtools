import 'dart:collection';

/// Class for storing a limited number string messages.
class LogStorage {
  static const int maxLogEntries = 3000;

  final Queue<String> _logs = Queue<String>();

  /// Adds [message] to the end of the log queue.
  ///
  /// If there are more than [maxLogEntries] messages in the logs, then the
  /// oldest message will be removed from the queue.
  void addLog(String message) {
    _logs.add(message);
    if (_logs.length > maxLogEntries) {
      _logs.removeFirst();
    }
  }

  /// Clears the queue of logs.
  void clear() {
    _logs.clear();
  }

  @override
  String toString() {
    return _logs.join('\n');
  }

  /// Static instance for storing the app's logs.
  static final LogStorage root = LogStorage();
}
