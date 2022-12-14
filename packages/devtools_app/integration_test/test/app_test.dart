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
    print('========== setUpAll ================');
    testApp = TestApp.fromEnvironment();
    expect(testApp.vmServiceUri, isNotNull);
  });

  tearDown(() {
    print('========== tearDown ================');
  });

  testWidgets('connect to app and switch tabs', (tester) async {
    print('========== begin connect screen loads test ================');
    // tester.testTextInput.register();
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
    print('========== end connect screen loads test ================');
  });

  // testWidgets('Connect screen loads 2', (tester) async {
  //   print('========== begin #2 connect screen loads test ================');
  //   await pumpDevTools(tester);
  //   expect(find.byType(LandingScreenBody), findsOneWidget);
  //   expect(find.text('No client connection'), findsOneWidget);

  //   print('========== end #2 connect screen loads test ================');
  // });

  // testWidgets('can connect to app', (tester) async {
  //   print('========== begin app connection test ================');
  //   await pumpDevTools(tester);
  //   await connectToTestApp(tester, testApp);
  //   expect(find.byType(LandingScreenBody), findsNothing);
  //   expect(find.text('No client connection'), findsNothing);
  //   print('========== end app connection test ================');

  //   // await binding.callbackManager.callback(params, testRunner)
  // });
}
