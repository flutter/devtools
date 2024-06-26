// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';
import 'package:logging/logging.dart';

import 'primitives/utils.dart';

/// Class for storing a limited number string messages.
class LogStorage {
  static const maxLogEntries = 4000;

  final _logs = Queue<LogRecord>();

  /// Adds [message] to the end of the log queue.
  ///
  /// If there are more than [maxLogEntries] messages in the logs, then the
  /// oldest message will be removed from the queue.
  void addLog(LogRecord record) {
    _logs.add(record);
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
    return toJsonLog();
  }

  String toJsonLog() {
    return _logs
        .map(
          (e) => jsonEncode({
            'level': e.level.name,
            'message': e.message,
            'timestamp': e.time.toUtc().toString(),
            'loggerName': e.loggerName,
            if (e.error != null) 'error': e.error.toString(),
            if (e.stackTrace != null) 'stackTrace': e.stackTrace.toString(),
          }),
        )
        .joinWithTrailing('\n');
  }

  /// Static instance for storing the app's logs.
  static final root = LogStorage();
}
