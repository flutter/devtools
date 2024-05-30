// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_test/helpers.dart';
import 'package:devtools_test/integration_test.dart';
import 'package:devtools_test/test_data.dart';
import 'package:flutter/material.dart';
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

      expect(find.text('_MyClass'), findsOneWidget);
      logStatus('4 - tapped _MyClass');

      await tester.tap(find.text('Diff Snapshots'));
      logStatus('5 - tapped Diff Snapshots');
      await tester.pumpAndSettle(longPumpDuration);
      logStatus('6 - pumped and settled');
      expect(find.text('Class type legend:'), findsOneWidget);
      logStatus('7 - found Class type legend');

      await tester.tap(find.text('Profile Memory'));
      logStatus('8 - tapped Profile Memory');
      await tester.pumpAndSettle(longPumpDuration);
      logStatus('9 - pumped and settled');
      expect(find.text('CSV'), findsOneWidget);
      logStatus('10 - found CSV');
    },
  );
}
