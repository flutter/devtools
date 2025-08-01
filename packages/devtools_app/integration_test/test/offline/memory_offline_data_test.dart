// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_test/helpers.dart';
import 'package:devtools_test/integration_test.dart';
import 'package:devtools_test/test_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// To run:
// dart run integration_test/run_tests.dart --target=integration_test/test/offline/memory_offline_data_test.dart

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Memory screen can load offline data', timeout: mediumTimeout, (
    tester,
  ) async {
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
  });
}
