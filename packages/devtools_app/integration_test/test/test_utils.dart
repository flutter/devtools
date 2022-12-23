// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/main.dart' as app;
import 'package:devtools_app/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const safePumpDuration = Duration(seconds: 3);
const longPumpDuration = Duration(seconds: 6);

Future<void> pumpDevTools(WidgetTester tester) async {
  // TODO(kenz): how can we share code across integration_test/test and
  // integration_test/test_infra? When trying to import, we get an error:
  // Error when reading 'org-dartlang-app:/test_infra/shared.dart': File not found
  const shouldEnableExperiments = bool.fromEnvironment('enable_experiments');
  await app.runDevTools(
    // ignore: avoid_redundant_argument_values
    shouldEnableExperiments: shouldEnableExperiments,
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
