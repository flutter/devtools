// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_test/helpers.dart';
import 'package:devtools_test/integration_test.dart';
import 'package:devtools_test/test_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// To run:
// dart run integration_test/run_tests.dart --target=integration_test/test/offline/memory_offline_data_test.dart

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Memory screen can load offline data',
    (tester) async {
      await pumpDevTools(tester);
      logStatus('1 - pumped devtools');
      await loadSampleData(tester, memoryFileName);
      logStatus('2 - loaded sample data');
      await tester.pumpAndSettle(longPumpDuration);
      logStatus('3 - pumped and settled');

      const diffTab = 'Diff Snapshots';
      const profileTab = 'Profile Memory';
      const traceTab = 'Trace Instances';

      expect(find.text('_MyClass'), findsOneWidget);
      logStatus('5 - found _MyClass');

      for (final tab in [diffTab, profileTab, traceTab]) {
        expect(find.text(tab), findsOneWidget);
        logStatus('6.$tab - found');
      }

      // expect(find.text('Trace Instances'), findsOneWidget);
      // logStatus('4 - found Trace Instances');

      // logStatus('5 - found _MyClass');
      // expect(find.text('Diff Snapshots'), findsOneWidget);
      // logStatus('6 - found Diff Snapshots');
      // expect(find.text('Profile Memory'), findsOneWidget);
      // logStatus('7 - found Profile Memory');

      // expect(find.text('_MyClass'), findsOneWidget);
      // logStatus('4 - found _MyClass');

      // // diff tab
      // await tester.tap(find.text('Diff Snapshots'));
      // logStatus('5 - tapped Diff Snapshots');
      // await tester.pumpAndSettle(longPumpDuration);
      // logStatus('6 - pumped and settled');
      // await tester.pumpAndSettle(longPumpDuration);
      // logStatus('6 - pumped and settled');

      // // profile tab
      // await tester.tap(find.text('Profile Memory'));
      // logStatus('8 - tapped Profile Memory');
      // await tester.pumpAndSettle(longPumpDuration);
      // logStatus('9 - pumped and settled');
      // expect(find.text('CSV'), findsOneWidget);
      // logStatus('10 - found CSV');
    },
  );
}
