import 'dart:math';

import 'package:devtools_app/src/shared/log_storage.dart';
import 'package:flutter_test/flutter_test.dart';

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
          const logMessage = 'This is a logMessage';

          logStorage.addLog(logMessage);

          expect(logStorage.toString(), logMessage);
        },
      );

      test(
        'clear',
        () async {
          const logMessage = 'This is a logMessage';

          logStorage.addLog(logMessage);
          expect(logStorage.toString(), logMessage);
          logStorage.clear();

          expect(logStorage.toString(), '');
        },
      );

      test(
        'log limit',
        () async {
          for (var i = 0; i < LogStorage.maxLogEntries - 10; i++) {
            logStorage.addLog(i.toString());
          }
          expect(
            logStorage.toString().split('\n').length,
            equals(LogStorage.maxLogEntries),
          );
          logStorage.addLog('Adding one more log');
          expect(
            logStorage.toString().split('\n').length,
            equals(LogStorage.maxLogEntries),
          );
        },
      );
    },
  );
}
