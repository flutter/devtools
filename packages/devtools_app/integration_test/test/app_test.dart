// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/app.dart';
import 'package:devtools_app/src/framework/landing_screen.dart';
import 'package:devtools_app/src/framework/release_notes/release_notes.dart';
import 'package:devtools_app/src/shared/primitives/simple_items.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

    // If the release notes viewer is open, close it.
    final releaseNotesView =
        tester.widget<ReleaseNotes>(find.byType(ReleaseNotes));
    if (releaseNotesView.releaseNotesController.releaseNotesVisible.value) {
      final closeReleaseNotesButton = find.descendant(
        of: find.byType(ReleaseNotes),
        matching: find.byType(IconButton),
      );
      expect(closeReleaseNotesButton, findsOneWidget);
      await tester.tap(closeReleaseNotesButton);
    }

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

    final screenTitles = (ScreenMetaData.values.toList()
          ..removeWhere((data) => !availableScreenIds.contains(data.id)))
        .map((data) => data.title);
    for (final title in screenTitles) {
      logStatus('switching to $title screen');
      await tester.tap(find.widgetWithText(Tab, title));
      // We use pump here instead of pumpAndSettle because pumpAndSettle will
      // never complete if there is an animation (e.g. a progress indicator).
      await tester.pump(safePumpDuration);
    }
  });
}
