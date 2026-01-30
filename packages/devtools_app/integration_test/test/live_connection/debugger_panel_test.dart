// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/debugger/breakpoints.dart';
import 'package:devtools_app/src/screens/debugger/call_stack.dart';
import 'package:devtools_app/src/screens/debugger/codeview.dart';
import 'package:devtools_app/src/service/service_extension_widgets.dart';
import 'package:devtools_test/helpers.dart';
import 'package:devtools_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// To run the test while connected to a flutter-tester device:
// dart run integration_test/run_tests.dart --target=integration_test/test/live_connection/debugger_panel_test.dart

// To run the test while connected to a chrome device:
// dart run integration_test/run_tests.dart --target=integration_test/test/live_connection/debugger_panel_test.dart --test-app-device=chrome

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp testApp;

  setUpAll(() {
    testApp = TestApp.fromEnvironment();
    expect(testApp.vmServiceUri, isNotNull);
  });

  testWidgets('Debugger panel', timeout: longTimeout, (tester) async {
    await pumpAndConnectDevTools(tester, testApp);
    await switchToScreen(
      tester,
      tabIcon: ScreenMetaData.debugger.icon,
      tabIconAsset: ScreenMetaData.debugger.iconAsset,
      screenId: ScreenMetaData.debugger.id,
    );
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

    logStatus('Navigating to line 55...');

    await goToLine(tester, lineNumber: 55);

    logStatus('looking for line 55');

    // Look for the line 55 gutter item:
    final gutter55Finder = findGutterItemWithText('55');
    expect(gutter55Finder, findsOneWidget);

    // Look for the line 55 line item:
    final line55Finder = findLineItemWithText("print('Hello!');");
    expect(line55Finder, findsOneWidget);

    await tester.pumpAndSettle(safePumpDuration);

    // Verify that the gutter item and line item are aligned:
    expect(
      areHorizontallyAligned(gutter55Finder, line55Finder, tester: tester),
      isTrue,
    );

    logStatus('setting a breakpoint');

    // Tap on the gutter for the line to set a breakpoint:
    await tester.tap(gutter55Finder);
    await tester.pumpAndSettle(longPumpDuration);

    logStatus('performing a hot restart');

    await tester.tap(find.byType(HotRestartButton));
    await tester.pumpAndSettle(longPumpDuration);

    logStatus('Navigating to line 28...');

    await goToLine(tester, lineNumber: 28);

    logStatus('looking for line 28');

    // Look for the line 30 gutter item:
    final gutter28Finder = findGutterItemWithText('28');
    expect(gutter28Finder, findsOneWidget);

    // Look for the line 28 line item:
    final line28Finder = findLineItemWithText('count++;');
    expect(line28Finder, findsOneWidget);

    // Verify that the gutter item and line item are aligned:
    expect(
      areHorizontallyAligned(gutter28Finder, line28Finder, tester: tester),
      isTrue,
    );

    logStatus('setting a breakpoint');

    // Tap on the gutter for the line to set a breakpoint:
    await tester.tap(gutter28Finder);
    await tester.pumpAndSettle(longPumpDuration);

    logStatus('verifying breakpoints');

    final bpSetBeforeRestart = findBreakpointWithText('main.dart:55');
    expect(bpSetBeforeRestart, findsOneWidget);

    logStatus('pausing at breakpoint');

    final topFrameFinder = findStackFrameWithText('incrementCounter');
    expect(topFrameFinder, findsOneWidget);
    expect(isLineFocused(line28Finder), isTrue);

    final countVariableFinder = find.textContaining('count:');
    expect(countVariableFinder, findsOneWidget);

    logStatus('inspecting variables');

    final callingFrameFinder = findStackFrameWithText('<closure>');
    expect(callingFrameFinder, findsOneWidget);

    logStatus('switching stackframes');

    // Tap on the stackframe:
    await tester.tap(callingFrameFinder);
    await tester.pumpAndSettle(safePumpDuration);

    logStatus('looking for the other_classes.dart file');

    final otherClassesFinder = await retryUntilFound(
      find.text('package:flutter_app/src/other_classes.dart'),
      tester: tester,
    );
    expect(otherClassesFinder, findsOneWidget);

    expect(
      find.text('package:flutter_app/src/other_classes.dart'),
      findsOneWidget,
    );

    logStatus('looking for the focused line');

    // Look for the line 46 gutter item:
    final gutter46Finder = findGutterItemWithText('46');
    expect(gutter46Finder, findsOneWidget);

    // Look for the line 46 line item:
    final line46Finder = findLineItemWithText('_action();');
    expect(line46Finder, findsOneWidget);

    // Verify that the gutter item and line item are aligned:
    expect(
      areHorizontallyAligned(gutter46Finder, line46Finder, tester: tester),
      isTrue,
    );

    // Verify that line 46 is focused:
    expect(isLineFocused(line46Finder), isTrue);
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

Future<void> goToLine(WidgetTester tester, {required int lineNumber}) async {
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

  logStatus('entering line number $lineNumber in the go-to-line dialog');

  final goToLineInputFinder = find.widgetWithText(TextField, 'Line Number');
  expect(goToLineInputFinder, findsOneWidget);
  await tester.enterText(goToLineInputFinder, '$lineNumber');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle(safePumpDuration);
}

T getWidgetFromFinder<T>(Finder finder) =>
    finder.first.evaluate().first.widget as T;

Finder findLineItemWithText(String text) => find.ancestor(
  of: find.textContaining(text),
  matching: find.byType(LineItem),
);

Finder findGutterItemWithText(String text) =>
    find.ancestor(of: find.text(text), matching: find.byType(GutterItem));

bool isLineFocused(Finder lineItemFinder) {
  final lineWidget = getWidgetFromFinder<LineItem>(lineItemFinder);
  return lineWidget.focused;
}

Finder findStackFrameWithText(String text) => find.descendant(
  of: find.byType(CallStack),
  matching: find.richTextContaining(text),
);

Finder findBreakpointWithText(String text) => find.descendant(
  of: find.byType(Breakpoints),
  matching: find.richTextContaining(text),
);
