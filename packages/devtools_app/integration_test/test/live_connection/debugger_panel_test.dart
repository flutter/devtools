// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/debugger/codeview.dart';
import 'package:devtools_test/devtools_integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    // Look for the main.dart file name:
    expect(find.text('package:flutter_app/main.dart'), findsOneWidget);

    // Look for the main.dart source code:
    final line1LineFinder = find.byKey(const Key('Line Item 1'));
    expect(line1LineFinder, findsOneWidget);
    expect(getSourceCodeAtLine(line1LineFinder), contains('FILE: main.dart'));

    logStatus(
      'Opening the "more" menu',
    );

    final moreMenuFinder = find.byType(PopupMenuButton<ScriptPopupMenuOption>);
    expect(moreMenuFinder, findsOneWidget);

    await tester.tap(moreMenuFinder);
    await tester.pump(longPumpDuration);

    logStatus(
      'Selecting the go-to-line menu option',
    );

    await tester.pumpAndSettle(longPumpDuration);
    final goToLineOptionFinder = find.textContaining('Go to line number');

    expect(goToLineOptionFinder, findsOneWidget);
    await tester.tap(goToLineOptionFinder);
    await tester.pump(safePumpDuration);

    logStatus(
      'Looking for the go-to-line dialog',
    );

    // Look for the line number text input:
    await tester.pumpAndSettle(safePumpDuration);
    final goToLineInputFinder = find.widgetWithText(TextField, 'Line Number');
    expect(goToLineInputFinder, findsOneWidget);

    logStatus(
      'Jumping to line 24',
    );

    // Enter "24" into the line number text input:
    await tester.enterText(goToLineInputFinder, '24');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(safePumpDuration);

    logStatus(
      'Looking for line 24',
    );

    // Look for the line 24 gutter item:
    await tester.pumpAndSettle(safePumpDuration);
    final line24GutterFinder = find.byKey(const Key('Gutter Item 24'));
    expect(line24GutterFinder, findsOneWidget);

    // Look for the line 24 line item:
    final line24LineFinder = find.byKey(const Key('Line Item 24'));
    expect(line24LineFinder, findsOneWidget);
    expect(getSourceCodeAtLine(line24LineFinder), contains('count++;'));

    logStatus(
      'Setting a breakpoint',
    );

    // Tap on the gutter for the line to set a breakpoint:
    await tester.tap(line24GutterFinder);
    await tester.pump(safePumpDuration);

    logStatus(
      'Pausing at breakpoint',
    );

    await tester.pumpAndSettle(safePumpDuration);
    final frameFinder = findStackFrameWithText('PeriodicAction.doEvery');
    expect(frameFinder, findsOneWidget);
  });
}

T getWidgetFromFinder<T>(Finder finder) =>
    finder.first.evaluate().first.widget as T;

String getSourceCodeAtLine(Finder lineItemFinder) {
  final lineWidget = getWidgetFromFinder<LineItem>(lineItemFinder);
  return lineWidget.lineContents.toPlainText();
}

Finder findStackFrameWithText(String text) => find.byWidgetPredicate(
      (Widget widget) {
        if (widget is RichText) {
          final widgetText = widget.text.toPlainText();
          return widgetText.contains(text);
        }
        return false;
      },
    );
