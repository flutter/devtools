// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/main.dart' as app;
import 'package:devtools_app/src/app.dart';
import 'package:devtools_app/src/framework/landing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const safePumpDuration = Duration(seconds: 5);

Future<void> pumpDevTools(WidgetTester tester) async {
  app.main();
  // Await a delay to ensure the widget tree has loaded. It is important to use
  // `pump` instead of `pumpAndSettle` here.
  await tester.pumpAndSettle(safePumpDuration);
  expect(find.byType(DevToolsApp), findsOneWidget);
}

Future<void> connectToTestApp(WidgetTester tester, TestApp testApp) async {
  final textFieldFinder = find.byType(TextField);
  print('entering text into connect dialog');
  await tester.enterText(textFieldFinder, testApp.vmServiceUri);
  await tester.tap(find.byKey(connectButtonKey));
  print('after tapping');
  await tester.pumpAndSettle(safePumpDuration);
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
        (jsonDecode(testArgs)).cast<String, Object>();
    return TestApp.parse(argsMap);
  }

  static const serviceUriKey = 'service_uri';

  final String vmServiceUri;

  void init() {
    // TODO(kenz): create a VmServiceWrapper object so that we can interact
    // with the test app's VmService from Dart code. See the use of [vmService]
    // in `test/test_infra/flutter_test_driver.dart`.
  }
}
