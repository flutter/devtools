// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/debugger/codeview.dart';
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
    await switchToScreen(tester, ScreenMetaData.debugger);
    await tester.pump(safePumpDuration);

    logStatus(
      'looking for the main.dart file',
    );

    // Look for the main.dart file name:
    expect(find.text('package:flutter_app/main.dart'), findsOneWidget);

    // Look for the main.dart source code:
    final line1LineFinder = find.byKey(const Key('Line Item 1'));
    expect(line1LineFinder, findsOneWidget);
    expect(getSourceCodeAtLine(line1LineFinder), contains('FILE: main.dart'));

    logStatus(
      'opening the "more" menu',
    );

    final moreMenuFinder = find.byType(PopupMenuButton<ScriptPopupMenuOption>);
    expect(moreMenuFinder, findsOneWidget);
    await tester.tap(moreMenuFinder);
    await tester.pumpAndSettle(safePumpDuration);

    logStatus(
      'selecting the go-to-line menu option',
    );

    final goToLineOptionFinder = find.textContaining('Go to line number');
    expect(goToLineOptionFinder, findsOneWidget);
    await tester.tap(goToLineOptionFinder);
    await tester.pumpAndSettle(safePumpDuration);

    logStatus(
      'entering line number in the go-to-line dialog',
    );

    final goToLineInputFinder = find.widgetWithText(TextField, 'Line Number');
    expect(goToLineInputFinder, findsOneWidget);
    await tester.enterText(goToLineInputFinder, '24');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle(safePumpDuration);

    logStatus(
      'looking for line 24',
    );

    // Look for the line 24 gutter item:
    final line24GutterFinder = find.byKey(const Key('Gutter Item 24'));
    expect(line24GutterFinder, findsOneWidget);

    // Look for the line 24 line item:
    final line24LineFinder = find.byKey(const Key('Line Item 24'));
    expect(line24LineFinder, findsOneWidget);
    expect(getSourceCodeAtLine(line24LineFinder), contains('count++;'));

    logStatus(
      'setting a breakpoint',
    );

    // Tap on the gutter for the line to set a breakpoint:
    await tester.tap(line24GutterFinder);
    await tester.pumpAndSettle(safePumpDuration);

    logStatus(
      'pausing at breakpoint',
    );

    final frameFinder = findStackFrameWithText('PeriodicAction.doEvery');
    expect(frameFinder, findsOneWidget);
    expect(isLineFocused(line24LineFinder), isTrue);

    logStatus(
      'inspecting variables',
    );

    final countVariableFinder = find.textContaining('count:');
    expect(countVariableFinder, findsOneWidget);

    logStatus(
      'switching stackframes',
    );

    // Tap on the stackframe:
    await tester.tap(frameFinder);
    await tester.pump(safePumpDuration);

    logStatus(
      'looking for the other_classes.dart file',
    );

    expect(
      find.text('package:flutter_app/src/other_classes.dart'),
      findsOneWidget,
    );

    logStatus(
      'looking for the focused line',
    );

    final line40LineFinder = find.byKey(const Key('Line Item 40'));
    expect(line40LineFinder, findsOneWidget);
    expect(getSourceCodeAtLine(line40LineFinder), contains('_action();'));
    expect(isLineFocused(line40LineFinder), isTrue);
  });
}

T getWidgetFromFinder<T>(Finder finder) =>
    finder.first.evaluate().first.widget as T;

String getSourceCodeAtLine(Finder lineItemFinder) {
  final lineWidget = getWidgetFromFinder<LineItem>(lineItemFinder);
  return lineWidget.lineContents.toPlainText();
}

bool isLineFocused(Finder lineItemFinder) {
  final lineWidget = getWidgetFromFinder<LineItem>(lineItemFinder);
  return lineWidget.focused;
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
