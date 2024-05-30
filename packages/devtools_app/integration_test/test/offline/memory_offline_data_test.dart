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
      logStatus('!!!!!!!! 1');
      await loadSampleData(tester, memoryFileName);
      logStatus('!!!!!!!! 2');
      await tester.pumpAndSettle(longPumpDuration);
      logStatus('!!!!!!!! 3');

      await tester.tap(find.text('_MyClass'));
      logStatus('!!!!!!!! 4');
      // await tester.pumpAndSettle(longPumpDuration);  // fails locally if this is uncommented
      // logStatus('!!!!!!!! 5');
      // expect(find.text('Traced allocations for: _MyClass'), findsOneWidget);
      // logStatus('!!!!!!!! 6');

      // await tester.tap(find.text('Diff Snapshots'));
      // logStatus('!!!!!!!! 7');
      // await tester.pumpAndSettle(shortPumpDuration);
      // logStatus('!!!!!!!! 8');
      // await tester.tap(find.textContaining('main'));
      // logStatus('!!!!!!!! 9');
      // await tester.pumpAndSettle(shortPumpDuration);
      // logStatus('!!!!!!!! 10');
      // expect(find.text('_MyHomePageState'), findsOneWidget);

      // logStatus('!!!!!!!! 11');
      // await tester.tap(find.text('Profile Memory'));
      // logStatus('!!!!!!!! 12');
      // await tester.pumpAndSettle(shortPumpDuration);
      // logStatus('!!!!!!!! 13');
      // expect(find.text('CSV'), findsOneWidget);
      // logStatus('!!!!!!!! 14');
      // expect(find.text('MyApp'), findsOneWidget);
      // logStatus('!!!!!!!! 15');
    },
  );
}
