// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/framework/landing_screen.dart';
import 'package:devtools_app/src/shared/primitives/simple_items.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_utils.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp testApp;

  setUpAll(() {
    testApp = TestApp.fromEnvironment();
    expect(testApp.vmServiceUri, isNotNull);
  });

  testWidgets('connect to app and switch tabs', (tester) async {
    await pumpDevTools(tester);
    expect(find.byType(LandingScreenBody), findsOneWidget);
    expect(find.text('No client connection'), findsOneWidget);

    logStatus('verify that we can connect to an app');
    await connectToTestApp(tester, testApp);
    expect(find.byType(LandingScreenBody), findsNothing);
    expect(find.text('No client connection'), findsNothing);

    logStatus('verify that we can load each DevTools screen');
    final tabs = tester.widgetList<Tab>(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(Tab),
      ),
    );
    expect(tabs.length, equals(9));

    // TODO(kenz): We need to account for conditional screens here - use 
    // [shouldShowScreen] helper
    final screenTitles = (ScreenMetaData.values.toList()
          ..removeWhere((data) => data == ScreenMetaData.simple))
        .map((data) => data.title);
    final screenFinders = screenTitles.map(
      (title) => find.widgetWithText(Tab, title),
    );
    for (final finder in screenFinders) {
      await tester.tap(finder);
      // We use pump here instead of pumpAndSettle because pumpAndSettle will
      // never complete if there is an animation (e.g. a progress indicator).
      await tester.pump(safePumpDuration);
    }
  });
}
