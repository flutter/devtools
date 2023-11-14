// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/main.dart' as app;
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_data/performance.dart';

const shortPumpDuration = Duration(seconds: 1);
const safePumpDuration = Duration(seconds: 3);
const longPumpDuration = Duration(seconds: 6);
const veryLongPumpDuration = Duration(seconds: 9);

/// Required to have multiple test cases in a file.
Future<void> resetHistory() async {
  // ignore: avoid-dynamic, necessary here.
  await (ui.PlatformDispatcher.instance.views.single as dynamic).resetHistory();
}

Future<void> pumpAndConnectDevTools(
  WidgetTester tester,
  TestApp testApp,
) async {
  await pumpDevTools(tester);
  expect(find.byType(ConnectDialog), findsOneWidget);
  expect(find.byType(ConnectedAppSummary), findsNothing);
  expect(find.text('No client connection'), findsOneWidget);
  _verifyFooterColor(tester, null);

  logStatus('verify that we can connect to an app');
  await connectToTestApp(tester, testApp);
  expect(find.byType(ConnectDialog), findsNothing);
  expect(find.byType(ConnectedAppSummary), findsOneWidget);
  expect(find.text('No client connection'), findsNothing);
  _verifyFooterColor(tester, darkColorScheme.primary);

  // If the release notes viewer is open, close it.
  final releaseNotesView =
      tester.widget<ReleaseNotesViewer>(find.byType(ReleaseNotesViewer));
  if (releaseNotesView.controller.isVisible.value) {
    final closeReleaseNotesButton = find.descendant(
      of: find.byType(ReleaseNotesViewer),
      matching: find.byType(IconButton),
    );
    expect(closeReleaseNotesButton, findsOneWidget);
    await tester.tap(closeReleaseNotesButton);
  }
}

void _verifyFooterColor(WidgetTester tester, Color? expectedColor) {
  final Container statusLineContainer = tester.widget(
    find
        .descendant(
          of: find.byType(StatusLine),
          matching: find.byType(Container),
        )
        .first,
  );
  expect(
    (statusLineContainer.decoration! as BoxDecoration).color,
    expectedColor,
  );
}

/// Switches to the DevTools screen with icon [tabIcon] and pumps the tester
/// to settle the UI.
Future<void> switchToScreen(
  WidgetTester tester, {
  required IconData tabIcon,
  required String screenId,
  bool warnIfTapMissed = true,
}) async {
  logStatus('switching to $screenId screen (icon $tabIcon)');
  final tabFinder = await findTab(tester, tabIcon);
  expect(tabFinder, findsOneWidget);

  await tester.tap(tabFinder, warnIfMissed: warnIfTapMissed);
  // We use pump here instead of pumpAndSettle because pumpAndSettle will
  // never complete if there is an animation (e.g. a progress indicator).
  await tester.pump(safePumpDuration);
}

/// Finds the tab with [icon] either in the top-level DevTools tab bar or in the
/// tab overflow menu for tabs that don't fit on screen.
Future<Finder> findTab(WidgetTester tester, IconData icon) async {
  // Open the tab overflow menu before looking for the tab.
  final tabOverflowButtonFinder = find.byType(TabOverflowButton);
  if (tabOverflowButtonFinder.evaluate().isNotEmpty) {
    await tester.tap(tabOverflowButtonFinder);
    await tester.pump(shortPumpDuration);
  }
  return find.widgetWithIcon(Tab, icon);
}

Future<void> pumpDevTools(WidgetTester tester) async {
  // TODO(kenz): how can we share code across integration_test/test and
  // integration_test/test_infra? When trying to import, we get an error:
  // Error when reading 'org-dartlang-app:/test_infra/shared.dart': File not found
  const shouldEnableExperiments = bool.fromEnvironment('enable_experiments');
  app.externalRunDevTools(
    integrationTestMode: true,
    // ignore: avoid_redundant_argument_values, by design
    shouldEnableExperiments: shouldEnableExperiments,
    sampleData: _sampleData,
  );
  final timeout = DateTime.now().add(const Duration(minutes: 3));
  while (true) {
    try {
      // If preferences aren't initialized yet then this will throw an error.
      preferences.isInitialized.value;
      break;
    } on TypeError catch (_) {
      if (DateTime.now().isBefore(timeout)) {
        await Future.delayed(const Duration(seconds: 5));
        continue;
      } else {
        // TypeError is used as a way to know when global variable is uninitialized.
        // ignore: avoid-throw-in-catch-block
        throw 'Timed out waiting for preferences to initialize';
      }
    }
  }
  // Wait for preferences to be initialized before continuing.
  if (!preferences.isInitialized.value) {
    final isDoneInitializing = Completer<void>();
    preferences.isInitialized.addListener(() {
      if (preferences.isInitialized.value) {
        isDoneInitializing.complete();
      }
    });
    await isDoneInitializing.future;
  }

  // Await a delay to ensure the widget tree has loaded.
  await tester.pumpAndSettle(veryLongPumpDuration);
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

Future<void> disconnectFromTestApp(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(DevToolsAppBar),
      matching: find.byIcon(Icons.home_rounded),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(ConnectToNewAppButton));
  await tester.pump(safePumpDuration);
}

void logStatus(String log) {
  // ignore: avoid_print, intentional print for test output
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
