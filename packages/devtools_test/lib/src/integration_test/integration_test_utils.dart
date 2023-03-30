// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_data/performance.dart';

const safePumpDuration = Duration(seconds: 3);
const longPumpDuration = Duration(seconds: 6);

/// Required to have multiple test cases in this file.
Future<void> resetHistory() async {
  await (ui.PlatformDispatcher.instance.views.single as dynamic).resetHistory();
}

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
  final releaseNotesView = tester
      .widget<SidePanelViewer>(find.byKey(SidePanelViewType.releaseNotes.key));
  if (releaseNotesView.controller.isVisible.value) {
    final closeReleaseNotesButton = find.descendant(
      of: find.byKey(SidePanelViewType.releaseNotes.key),
      matching: find.byType(IconButton),
    );
    expect(closeReleaseNotesButton, findsOneWidget);
    await tester.tap(closeReleaseNotesButton);
  }
}

Future<void> switchToScreen(WidgetTester tester, ScreenMetaData screen) async {
  final screenTitle = screen.title;
  logStatus('switching to $screenTitle screen');
  await tester.tap(find.widgetWithText(Tab, screenTitle));
  // We use pump here instead of pumpAndSettle because pumpAndSettle will
  // never complete if there is an animation (e.g. a progress indicator).
  await tester.pump(safePumpDuration);
}

Future<void> pumpDevTools(WidgetTester tester) async {
  // TODO(kenz): how can we share code across integration_test/test and
  // integration_test/test_infra? When trying to import, we get an error:
  // Error when reading 'org-dartlang-app:/test_infra/shared.dart': File not found
  const shouldEnableExperiments = bool.fromEnvironment('enable_experiments');
  await app.externalRunDevTools(
    // ignore: avoid_redundant_argument_values
    shouldEnableExperiments: shouldEnableExperiments,
    sampleData: _sampleData,
  );

  // Await a delay to ensure the widget tree has loaded.
  await tester.pumpAndSettle(longPumpDuration);
  expect(find.byType(DevToolsApp), findsOneWidget);
}

Future<void> connectToTestApp(WidgetTester tester, TestApp testApp) async {
  final textFieldFinder = find.byType(TextField);
  // TODO(https://github.com/flutter/flutter/issues/89749): use
  // `tester.enterText` once this issue is fixed.
  (tester.firstWidget(textFieldFinder) as TextField).controller?.text =
      testApp.vmServiceUri;
  await tester.tap(
    find.ancestor(
      of: find.text('Connect'),
      matching: find.byType(ElevatedButton),
    ),
  );
  await tester.pumpAndSettle(safePumpDuration);
}

void logStatus(String log) {
  print('TEST STATUS: $log');
}

class TestApp {
  TestApp._({required this.vmServiceUri});

  factory TestApp.parse(Map<String, Object> json) {
    final serviceUri = json[serviceUriKey] as String?;
    if (serviceUri == null) {
      throw Exception('Cannot create a TestApp with a null service uri.');
    }
    return TestApp._(vmServiceUri: serviceUri);
  }

  factory TestApp.fromEnvironment() {
    const testArgs = String.fromEnvironment('test_args');
    final Map<String, Object> argsMap =
        jsonDecode(testArgs).cast<String, Object>();
    return TestApp.parse(argsMap);
  }

  static const serviceUriKey = 'service_uri';

  final String vmServiceUri;
}

Future<void> verifyScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  String screenshotName, {
  // TODO(https://github.com/flutter/flutter/issues/118470): remove this.
  bool lastScreenshot = false,
}) async {
  const updateGoldens = bool.fromEnvironment('update_goldens');
  logStatus('verify $screenshotName screenshot');
  await binding.takeScreenshot(
    screenshotName,
    {
      'update_goldens': updateGoldens,
      'last_screenshot': lastScreenshot,
    },
  );
}

Future<void> loadSampleData(WidgetTester tester, String fileName) async {
  await tester.tap(find.byType(DropdownButton<DevToolsJsonFile>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(fileName).last);
  await tester.pump(safePumpDuration);
  await tester.tap(find.text('Load sample data'));
  await tester.pump(longPumpDuration);
}

const performanceFileName = 'performance_data.json';

final _sampleData = <DevToolsJsonFile>[
  DevToolsJsonFile(
    name: performanceFileName,
    lastModifiedTime: DateTime.now(),
    data: jsonDecode(jsonEncode(samplePerformanceData)),
  ),
];
