// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/debugger/codeview.dart';
// import 'package:devtools_app/src/screens/debugger/file_search.dart';
import 'package:devtools_test/devtools_integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// To run:
// dart run integration_test/run_tests.dart --target=integration_test/test/live_connection/debugger_panel_test.dart

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp testApp;

  setUpAll(() {
    testApp = TestApp.fromEnvironment();
    expect(testApp.vmServiceUri, isNotNull);
  });

  testWidgets('Debugger panel', (tester) async {
    await pumpAndConnectDevTools(tester, testApp);

    logStatus(
      'Switching to the debugger panel',
    );

    await switchToScreen(tester, ScreenMetaData.debugger);
    await tester.pump(safePumpDuration);

    logStatus(
      'Looking for the main.dart file',
    );

    expectCurrentFileStartsWith(mainFileSourceCodeSnippet);
    final mainFileNameFinder = find.text(mainFileName);
    expect(mainFileNameFinder, findsOneWidget);

    logStatus(
      'Setting a breakpoint',
    );

    final line22GutterFinder = find.byKey(const Key('Gutter Item 22'));
    expect(line22GutterFinder, findsOneWidget);
    await tester.tap(line22GutterFinder);
    await tester.pump(safePumpDuration);

    logStatus(
      'Pausing at breakpoint',
    );

    expect(
      find.text('main.dart:22'),
      findsOneWidget,
    );

    logStatus(
      'Navigating to a stackframe',
    );

    final frameFinder = find.text('PeriodicAction.doEvery');
    expect(frameFinder, findsOneWidget);
    await tester.tap(frameFinder);
    await tester.pump(safePumpDuration);

    logStatus(
      'Verifying the file has changed',
    );

    final otherFileNameFinder = find.text(otherFileName);
    expect(otherFileNameFinder, findsOneWidget);


    // Inspect variables.
    /* 

    logStatus(
      'Opening the file opener',
    );

    await tester.tap(mainFileNameFinder);
    await tester.pump(safePumpDuration);

    logStatus(
      'Looking for file opener',
    );

    final fileOpenerFinder = find.widgetWithText(TextField, 'Open file');
    expect(fileOpenerFinder, findsOneWidget);

    logStatus(
      'Entering a search query in the file opener',
    );

    await tester.enterText(fileOpenerFinder, 'flutter_app');
    await tester.pump(safePumpDuration);

    final otherFileNameFinder = find.text(otherFileName);
    expect(otherFileNameFinder, findsOneWidget);

    logStatus(
      'Switching files',
    );

    await tester.tap(otherFileNameFinder);
    await tester.pump(safePumpDuration);

    expect(fileOpenerFinder, findsNothing);
    expect(mainFileNameFinder, findsNothing);
    expect(otherFileNameFinder, findsOneWidget);
    expectCurrentFileStartsWith(otherFileSourceCodeSnippet);
    */
  });
}

void expectCurrentFileStartsWith(String sourceCode) {
  final stringMatches = sourceCode.split('\n');
  final lines = find.byType(LineItem);
  expect(lines, findsAtLeastNWidgets(stringMatches.length));
  for (int i = 0; i < stringMatches.length; i++) {
    final stringMatch = stringMatches[i];
    final line = getWidgetFromFinder<LineItem>(lines.at(i));
    expect(
      line.lineContents.toPlainText().trim(),
      contains(
        stringMatch.trim(),
      ),
    );
  }
}

void expectFirstNLinesContain(List<String> stringMatches) {
  final lines = find.byType(LineItem);
  expect(lines, findsAtLeastNWidgets(stringMatches.length));
  for (int i = 0; i < stringMatches.length; i++) {
    final stringMatch = stringMatches[i];
    final line = getWidgetFromFinder<LineItem>(lines.at(i));
    expect(line.lineContents.toPlainText(), contains(stringMatch));
  }
}

T getWidgetFromFinder<T>(Finder finder) =>
    finder.first.evaluate().first.widget as T;

const mainFileName = 'package:flutter_app/main.dart';

const mainFileSourceCodeSnippet = '''
// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
// Unused imports are useful for testing autocomplete.
// ignore_for_file: unused_import
import 'src/autocomplete.dart';
import 'src/other_classes.dart';

void main() => runApp(MyApp());

bool topLevelFieldForTest = false;

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable, for testing.
    var count = 0;
    PeriodicAction(() {
      count++;
    }).doEvery(const Duration(seconds: 1));
''';

const otherFileName = 'package:flutter_app/src/other_classes.dart';

const otherFileSourceCodeSnippet = '''
// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

// Unused class in the sample application that is a widget.
//
// This is a fairly long description so that we can make sure that scrolling to
// a line works when we are paused at a breakpoint.
class MyOtherWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}
''';


    // Find the [DebuggerController] to access its data.
    // final debuggerScreenFinder = find.byType(DebuggerScreenBody);
    // expect(debuggerScreenFinder, findsOneWidget);
    // final screenState =
    //     tester.state<DebuggerScreenBodyState>(debuggerScreenFinder);
    // final debuggerController = screenState.controller;

    // expect(debuggerController, isNotNull);
