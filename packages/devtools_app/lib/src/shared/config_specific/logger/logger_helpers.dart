import 'package:logging/logging.dart';

import '../../log_storage.dart';
import 'logger.dart';

/// Helper for setting the log level for the global [Logger].
void setDevToolsLoggingLevel(Level level) {
  Logger.root.level = level;
  Logger.root.warning('DevTool\'s log level changed to ${level.name}');
}

/// Helper for initializing the [Logger] record handler.
void initDevToolsLogging() {
  Logger.root.onRecord.listen((record) {
    // As long as a log was recorded then it should be added to the LogStorage.
    LogStorage.root.addLog(record);

    // All logs with level [Level.INFO] and above, should be printed to the
    // console.
    if (record.level == Level.INFO) {
      log(record.message);
    } else if (record.level == Level.WARNING) {
      log(record.message, LogLevel.warning);
    } else if (record.level == Level.SEVERE) {
      log(record.message, LogLevel.error);
    } else if (record.level == Level.SHOUT) {
      log(record.message, LogLevel.error);
    }
  });
}
