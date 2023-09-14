// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
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
    await resetHistory();
  });

  testWidgets('connect to app and switch tabs', (tester) async {
    await pumpAndConnectDevTools(tester, testApp);

    // For the sake of this test, do not show extension screens by default.
    preferences.devToolsExtensions.showOnlyEnabledExtensions.value = true;
    await tester.pumpAndSettle(shortPumpDuration);

    logStatus('verify that we can load each DevTools screen');
    final availableScreenIds = <String>[];
    for (final screen in devtoolsScreens!) {
      if (shouldShowScreen(screen.screen)) {
        availableScreenIds.add(screen.screen.screenId);
      }
    }
    final tabs = tester.widgetList<Tab>(
      find.descendant(
        of: find.byType(DevToolsAppBar),
        matching: find.byType(Tab),
      ),
    );

    var numTabs = tabs.length;
    if (numTabs < availableScreenIds.length) {
      final tabOverflowMenuFinder = find.descendant(
        of: find.byType(TabOverflowButton),
        matching: find.byType(MenuAnchor),
      );
      expect(tabOverflowMenuFinder, findsOneWidget);
      final menuChildren =
          tester.widget<MenuAnchor>(tabOverflowMenuFinder).menuChildren;
      numTabs += menuChildren.length;
    }

    expect(numTabs, availableScreenIds.length);

    final screens = (ScreenMetaData.values.toList()
      ..removeWhere((data) => !availableScreenIds.contains(data.id)));
    for (final screen in screens) {
      await switchToScreen(
        tester,
        tabIcon: screen.icon!,
        screenId: screen.id,
      );
    }
  });
}
