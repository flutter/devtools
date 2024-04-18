// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/main.dart' as app;
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/utils.dart';
import '../test_data/sample_data.dart';

/// Required to have multiple test cases in a file.
Future<void> resetHistory() async {
  // ignore: avoid-dynamic, necessary here.
  await (ui.PlatformDispatcher.instance.views.single
          as dynamic /* EngineFlutterWindow */)
      // This dynamic call is necessary as `EngineFlutterWindow` is declared in
      // the web-specific implementation of the Flutter Engine, at
      // `lib/web_ui/lib/src/engine/window.dart` in the Flutter engine
      // repository.
      // ignore: avoid_dynamic_calls
      .resetHistory();
}

Future<void> pumpAndConnectDevTools(
  WidgetTester tester,
  TestApp testApp,
) async {
  await pumpDevTools(tester);
  expect(find.byType(ConnectInput), findsOneWidget);
  expect(find.byType(ConnectedAppSummary), findsNothing);
  expect(find.text('No client connection'), findsOneWidget);
  _verifyFooterColor(tester, null);

  logStatus('verify that we can connect to an app');
  await connectToTestApp(tester, testApp);
  expect(find.byType(ConnectInput), findsNothing);
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

Future<void> pumpDevTools(WidgetTester tester) async {
  // TODO(kenz): how can we share code across integration_test/test and
  // integration_test/test_infra? When trying to import, we get an error:
  // Error when reading 'org-dartlang-app:/test_infra/shared.dart': File not found
  const shouldEnableExperiments = bool.fromEnvironment('enable_experiments');
  app.externalRunDevTools(
    integrationTestMode: true,
    // ignore: avoid_redundant_argument_values, by design
    shouldEnableExperiments: shouldEnableExperiments,
    sampleData: sampleData,
  );

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
  await tester.pumpAndSettle(longPumpDuration);
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

class TestApp {
  TestApp._({required this.vmServiceUri});

  factory TestApp.fromJson(Map<String, Object> json) {
    final serviceUri = json[serviceUriKey] as String?;
    if (serviceUri == null) {
      throw Exception('Cannot create a TestApp with a null service uri.');
    }
    return TestApp._(vmServiceUri: serviceUri);
  }

  factory TestApp.fromEnvironment() {
    const testArgs = String.fromEnvironment('test_args');
    final argsMap = (jsonDecode(testArgs) as Map).cast<String, Object>();
    return TestApp.fromJson(argsMap);
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
