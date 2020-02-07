// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:io' as io;

import 'package:devtools_app/src/flutter/app.dart';
import 'package:devtools_app/src/flutter/connect_screen.dart';
import 'package:devtools_app/src/framework/framework_core.dart';
import 'package:devtools_app/src/inspector/flutter/inspector_screen.dart';
import 'package:devtools_testing/support/file_utils.dart';
import 'package:devtools_testing/support/flutter_test_driver.dart';
import 'package:devtools_testing/support/flutter_test_environment.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';
// import 'package:flutter_test/flutter_test.dart';

// import '../../support/cli_test_driver.dart';

Future<void> main() async {
  final FlutterTestEnvironment env = FlutterTestEnvironment(
    const FlutterRunConfiguration(withDebugger: true),
  );

  await runIntegrationTest(env);
}

Future<void> runIntegrationTest(FlutterTestEnvironment env) async {
  Uri uri;
  Process process;

  env.afterNewSetup = () async {};

  // await env.setupEnvironment();

  group('Whole app', () {
    FlutterDriver driver;
    tearDownAll(() async {
      if (driver != null) await driver.close();
      // await env.tearDownEnvironment(force: true);
    });

    setUpAll(() async {
      driver = await FlutterDriver.connect();
    });
    test('Is connected', () async {
      expect(await driver.getText(find.text('Connect')), 'Connect');
    });
    /** 
    testWidgets('Connects to a Dart app', (WidgetTester tester) async {
      final List<Future<void>> matchGoldens = [];
      await tester.runAsync(() async {
        HttpOverrides.global = null;
        final app = DevToolsApp();

        FrameworkCore.init('');

        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        expect(find.byType(ConnectScreenBody), findsOneWidget);
        print(uri);
        await tester.enterText(
          find.byType(TextField),
          env.flutter.vmServiceWsUri.toString(),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.tap(find.byType(RaisedButton));

        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(InspectorScreenBody), findsOneWidget);
        matchGoldens.add(expectLater(
          find.byWidget(app),
          matchesGoldenFile('goldens/InspectorScreen.png'),
        ));

        await env.tearDownEnvironment();
      });

      await Future.wait(matchGoldens);
    });
    */
  });
}
