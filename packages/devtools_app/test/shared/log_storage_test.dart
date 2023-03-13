import 'dart:math';

import 'package:devtools_app/src/shared/log_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

void main() {
  group(
    'LogStorage',
    () {
      late LogStorage logStorage;
      setUp(() {
        logStorage = LogStorage();
      });

      test(
        'addLog',
        () async {
          final logMessage =
              LogRecord(Level.INFO, 'This is a logMessage', 'testLoggerName');

          logStorage.addLog(logMessage);

          expect(logStorage.toString(), contains(logMessage.level.name));
          expect(logStorage.toString(), contains(logMessage.loggerName));
          expect(logStorage.toString(), contains(logMessage.message));
        },
      );

      test(
        'clear',
        () async {
          final logRecord =
              LogRecord(Level.INFO, 'This is a logMessage', 'test');

          logStorage.addLog(logRecord);
          expect(logStorage.toString(), contains(logRecord.message));
          logStorage.clear();

          expect(logStorage.toString(), '');
        },
      );

      test(
        'log limit',
        () async {
          for (var i = 0; i < LogStorage.maxLogEntries; i++) {
            final logRecord =
                LogRecord(Level.INFO, 'This is logMessage: $i', 'test');
            logStorage.addLog(logRecord);
          }

          expect(
            logStorage.toString().split('\n').length,
            equals(LogStorage.maxLogEntries),
          );

          final extraLogRecord =
              LogRecord(Level.INFO, 'This is one extra Log Message', 'test');
          logStorage.addLog(extraLogRecord);

          expect(
            logStorage.toString().split('\n').length,
            equals(LogStorage.maxLogEntries),
          );
          expect(logStorage.toString(), contains(extraLogRecord.level.name));
          expect(logStorage.toString(), contains(extraLogRecord.loggerName));
          expect(logStorage.toString(), contains(extraLogRecord.message));
        },
      );
    },
  );
}
