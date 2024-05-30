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
      await loadSampleData(tester, memoryFileName);
      await tester.pumpAndSettle(longPumpDuration);

      await tester.tap(find.text('_MyClass'));
      print(1111114);
      await tester.pumpAndSettle(longPumpDuration);
      print(1111115);
      expect(find.text('Traced allocations for: _MyClass'), findsOneWidget);
      print(1111116);

      await tester.tap(find.text('Diff Snapshots'));
      print(1111117);
      await tester.pumpAndSettle(shortPumpDuration);
      print(1111118);
      await tester.tap(find.textContaining('main'));
      print(1111119);
      await tester.pumpAndSettle(shortPumpDuration);
      print(11111110);
      expect(find.text('_MyHomePageState'), findsOneWidget);

      print(11111111);
      await tester.tap(find.text('Profile Memory'));
      print(11111112);
      await tester.pumpAndSettle(shortPumpDuration);
      print(11111113);
      expect(find.text('CSV'), findsOneWidget);
      print(11111114);
      expect(find.text('MyApp'), findsOneWidget);
      print(11111115);
    },
  );
}
