// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:logging/logging.dart';

import '../../constants.dart';
import '../../log_storage.dart';
import 'logger.dart';

/// Helper for setting the log level for the global [Logger].
void setDevToolsLoggingLevel(Level level) {
  Logger.root.level = level;
  Logger.root.warning('DevTools log level changed to ${level.name}');
}

/// Helper for initializing the [Logger] record handler.
void initDevToolsLogging() {
  Logger.root.onRecord.listen((record) {
    // As long as a log was recorded then it should be added to the LogStorage.
    LogStorage.root.addLog(record);

    // All logs with level [basicLoggingLevel] and above, should be printed to the
    // console.
    if (record.level >= basicLoggingLevel) {
      var logLevel = LogLevel.debug;
      if (record.level == Level.WARNING) {
        logLevel = LogLevel.warning;
      } else if (record.level == Level.SEVERE) {
        logLevel = LogLevel.error;
      } else if (record.level == Level.SHOUT) {
        logLevel = LogLevel.error;
      }
      printToConsole(record.message, logLevel);
    }
  });
}
