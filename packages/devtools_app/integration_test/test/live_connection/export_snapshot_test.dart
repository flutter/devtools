// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_test/helpers.dart';
import 'package:devtools_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// To run:
// dart run integration_test/run_tests.dart --target=integration_test/test/live_connection/app_test.dart

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

  testWidgets('connect to app and switch tabs', (tester) async {
    await pumpAndConnectDevTools(tester, testApp);

    // For the sake of this test, do not show extension screens by default.
    preferences.devToolsExtensions.showOnlyEnabledExtensions.value = true;
    await tester.pumpAndSettle(shortPumpDuration);

    logStatus('verify that we can load each DevTools screen');
    await navigateThroughDevToolsScreens(tester);
  });
}
