// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/primitives/simple_items.dart';
import 'package:devtools_test/devtools_integration_test.dart';
import 'package:flutter/material.dart';
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
    // This is required to have multiple test cases in this file.
    await (ui.window as dynamic).resetHistory();
  });

  testWidgets('connect to app and switch tabs', (tester) async {
    await pumpAndConnectDevTools(tester, testApp);

    logStatus('verify that we can load each DevTools screen');
    final availableScreenIds = <String>[];
    for (final screen in devtoolsScreens!) {
      if (shouldShowScreen(screen.screen)) {
        availableScreenIds.add(screen.screen.screenId);
      }
    }
    final tabs = tester.widgetList<Tab>(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(Tab),
      ),
    );
    expect(tabs.length, equals(availableScreenIds.length));

    final screens = (ScreenMetaData.values.toList()
      ..removeWhere((data) => !availableScreenIds.contains(data.id)));
    for (final screen in screens) {
      await switchToScreen(tester, screen);
    }
  });
}
