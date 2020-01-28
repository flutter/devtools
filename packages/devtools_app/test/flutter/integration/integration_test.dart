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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/cli_test_driver.dart';

void main() async {
  Uri uri;
  Process process;
  final override = _RealHttpOverride();

  setUpAll(() async {
    await runZoned(() async {
      HttpOverrides.global = override;
      FrameworkCore.init('');
      compensateForFlutterTestDirectoryBug();
      print(io.Directory(io.Directory.current.parent.parent.path +
          '/case_study/memory_leak/'));
      process = await Process.start(
        'flutter',
        <String>['run', '-d', 'flutter-tester'],
        workingDirectory: io.Directory(io.Directory.current.parent.parent.path +
                '/case_study/memory_leak/')
            .path,
      );

      final Stream<String> lines = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      final StreamController<String> lineController =
          StreamController<String>.broadcast();
      final Completer<String> completer = Completer<String>();
      const prefix =
          'An Observatory debugger and profiler on Flutter test device '
          'is available at: ';
      lines.listen((String line) {
        print(line);
        if (completer.isCompleted) {
          lineController.add(line);
        } else if (prefix.matchAsPrefix(line) != null) {
          print('completing $prefix');
          completer.complete(line);
        }
      });

      // Observatory listening on http://127.0.0.1:9595/(token)
      final observatoryText = await completer.future;
      print(observatoryText);
      final observatoryUri = observatoryText.replaceAll(prefix, '');
      uri = Uri.parse(observatoryUri);
      print(uri);

      if (uri == null || !uri.isAbsolute) {
        throw 'Could not parse VM Service URI from $observatoryText';
      }
      // print('waiting 5 minutes for input');
      // sleep(const Duration(minutes: 5));
      // print('Done waiting');
    });
  });

  group('Whole app', () {
    testWidgets('Connects to a Dart app', (WidgetTester tester) async {
      HttpOverrides.global = override;
      final app = DevToolsApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.byType(ConnectScreenBody), findsOneWidget);
      print(uri);
      await tester.enterText(
        find.byType(TextField),
        '$uri',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.tap(find.byType(RaisedButton));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await expectLater(
        find.byWidget(app),
        matchesGoldenFile('InspectorScreen.png'),
      );
      expect(find.byType(InspectorScreenBody), findsOneWidget);
    });

    tearDownAll(() {
      process.kill();
    });
  });
}

class _RealHttpOverride extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext context) {
    return HttpClient(context: context);
  }

  @override
  String findProxyFromEnvironment(Uri url, Map<String, String> environment) {
    return HttpClient.findProxyFromEnvironment(url, environment: environment);
  }
}
