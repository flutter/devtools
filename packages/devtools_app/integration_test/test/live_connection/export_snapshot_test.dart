// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'memory_screen_helpers.dart';

// To run:
// dart run integration_test/run_tests.dart --target=integration_test/test/live_connection/export_snapshot_test.dart

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp testApp;

  setUpAll(() {
    testApp = TestApp.fromEnvironment();
    expect(testApp.vmServiceUri, isNotNull);
  });

  tearDown(() async {
    await resetHistory();
  });

  testWidgets('Export snapshot', (tester) async {
    await pumpAndConnectDevTools(tester, testApp);
    await prepareMemoryUI(tester);
    await takeHeapSnapshot(tester);
    await openContextMenuForSnapshot('main-1', tester);
    await tapAndPumpWidget(tester, find.text('Export'));
  });
}
