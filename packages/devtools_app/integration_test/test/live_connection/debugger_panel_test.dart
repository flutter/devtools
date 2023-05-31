// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/framework/about_dialog.dart';
import 'package:devtools_app/src/screens/debugger/call_stack.dart';
import 'package:devtools_app/src/screens/debugger/codeview.dart';
import 'package:devtools_test/devtools_integration_test.dart';
import 'package:devtools_test/devtools_test.dart';
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

    logStatus('looking for the main.dart file');

    // Look for the main.dart file name:
    expect(find.text('package:flutter_app/main.dart'), findsOneWidget);

    // Look for the main.dart source code:
    final firstLineFinder = findLineItemWithText('FILE: main.dart');
    expect(firstLineFinder, findsOneWidget);

    // Look for the first gutter item:
    final firstGutterFinder = findGutterItemWithText('1');
    expect(firstGutterFinder, findsOneWidget);

    // Verify that the gutter item and line item are aligned:
    expect(
      areHorizontallyAligned(
        firstGutterFinder,
        firstLineFinder,
        tester: tester,
      ),
      isTrue,
    );

    logStatus('opening the "more" menu');

    final moreMenuFinder = find.byType(PopupMenuButton<ScriptPopupMenuOption>);
    expect(moreMenuFinder, findsOneWidget);
    await tester.tap(moreMenuFinder);
    await tester.pumpAndSettle(safePumpDuration);

    logStatus('selecting the go-to-line menu option');

    final goToLineOptionFinder = find.textContaining('Go to line number');
    expect(goToLineOptionFinder, findsOneWidget);
    await tester.tap(goToLineOptionFinder);
    await tester.pumpAndSettle(safePumpDuration);

    logStatus('entering line number in the go-to-line dialog');

    final goToLineInputFinder = find.widgetWithText(TextField, 'Line Number');
    expect(goToLineInputFinder, findsOneWidget);
    await tester.enterText(goToLineInputFinder, '24');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle(safePumpDuration);

    logStatus('looking for line 24');

    // Look for the line 24 gutter item:
    final gutter24Finder = findGutterItemWithText('24');
    expect(gutter24Finder, findsOneWidget);

    // Look for the line 24 line item:
    final line24Finder = findLineItemWithText('count++;');
    expect(line24Finder, findsOneWidget);

    // Verify that the gutter item and line item are aligned:
    expect(
      areHorizontallyAligned(
        gutter24Finder,
        line24Finder,
        tester: tester,
      ),
      isTrue,
    );

    logStatus('setting a breakpoint');

    // Tap on the gutter for the line to set a breakpoint:
    await tester.tap(gutter24Finder);
    await tester.pumpAndSettle(safePumpDuration);

    logStatus('pausing at breakpoint');

    final frameFinder = findStackFrameWithText('PeriodicAction.doEvery');
    expect(frameFinder, findsOneWidget);
    expect(isLineFocused(line24Finder), isTrue);

    logStatus('inspecting variables');

    final countVariableFinder = find.textContaining('count:');
    expect(countVariableFinder, findsOneWidget);

    logStatus('switching stackframes');

    // Tap on the stackframe:
    await tester.tap(frameFinder);
    await tester.pump(safePumpDuration);

    logStatus('looking for the other_classes.dart file');

    expect(
      find.text('package:flutter_app/src/other_classes.dart'),
      findsOneWidget,
    );

    logStatus('looking for the focused line');

    // Look for the line 40 gutter item:
    final gutter40Finder = findGutterItemWithText('40');
    expect(gutter40Finder, findsOneWidget);

    // Look for the line 40 line item:
    final line40Finder = findLineItemWithText('_action();');
    expect(line40Finder, findsOneWidget);

    // Verify that the gutter item and line item are aligned:
    expect(
      areHorizontallyAligned(
        gutter40Finder,
        line40Finder,
        tester: tester,
      ),
      isTrue,
    );

    // Verify that line 40 is focused:
    expect(isLineFocused(line40Finder), isTrue);
  });
}

bool areHorizontallyAligned(
  Finder widgetAFinder,
  Finder widgetBFinder, {
  required WidgetTester tester,
}) {
  final widgetACenter = tester.getCenter(widgetAFinder);
  final widgetBCenter = tester.getCenter(widgetBFinder);

  return widgetACenter.dy == widgetBCenter.dy;
}

T getWidgetFromFinder<T>(Finder finder) =>
    finder.first.evaluate().first.widget as T;

Finder findLineItemWithText(String text) => find.ancestor(
      of: find.selectableTextContaining(text),
      matching: find.byType(LineItem),
    );

Finder findGutterItemWithText(String text) => find.ancestor(
      of: find.text(text),
      matching: find.byType(GutterItem),
    );

bool isLineFocused(Finder lineItemFinder) {
  final lineWidget = getWidgetFromFinder<LineItem>(lineItemFinder);
  return lineWidget.focused;
}

Finder findStackFrameWithText(String text) => find.descendant(
      of: find.byType(CallStack),
      matching: find.richTextContaining(text),
    );
