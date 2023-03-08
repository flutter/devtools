// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/framework/landing_screen.dart';
import 'package:devtools_app/src/framework/release_notes/release_notes.dart';
import 'package:devtools_app/src/screens/performance/tabbed_performance_view.dart';
import 'package:devtools_app/src/shared/primitives/simple_items.dart';
import 'package:devtools_test/devtools_integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> pumpAndConnectDevTools(
  WidgetTester tester,
  TestApp testApp,
) async {
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
}
