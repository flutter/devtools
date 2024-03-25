// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/memory/panes/control/primary_controls.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/widgets/snapshot_list.dart';
import 'package:devtools_app/src/screens/memory/shared/primitives/instance_context_menu.dart';
import 'package:devtools_app/src/shared/console/widgets/console_pane.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_screen_helpers.dart';

class EvalTester {
  EvalTester(this.tester);

  final WidgetTester tester;

  Future<Finder?> tapAndPump(
    Finder finder, {
    Duration? duration,
    Finder? next,
    String? description,
  }) async {
    return await tapAndPumpWidget(
      tester,
      finder,
      duration: duration,
      description: description,
      next: next,
    );
  }

  /// Tests if eval returns expected response by searching for response text.
  Future<void> testEval(String expression, Finder expectedResponse) async {
    await tapAndPump(find.byType(AutoCompleteSearchField));
    await tester.enterText(find.byType(AutoCompleteSearchField), expression);
    await tester.pump(safePumpDuration);
    await _pressEnter();

    expect(expectedResponse, findsOneWidget);
  }

  Future<void> _pressEnter() async {
    // TODO(polina-c): Figure out why one time sometimes is not enough.
    // https://github.com/flutter/devtools/issues/5436
    await simulateKeyDownEvent(LogicalKeyboardKey.enter);
    await simulateKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await simulateKeyDownEvent(LogicalKeyboardKey.enter);
    await simulateKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump(longPumpDuration);
  }

  /// Prepares the UI of the inspector screen so that the eval-related
  /// elements are visible on the screen for testing.
  Future<void> prepareInspectorUI() async {
    // Open the inspector screen.
    await switchToScreen(
      tester,
      tabIcon: ScreenMetaData.inspector.icon!,
      screenId: ScreenMetaData.inspector.id,
    );
    await tester.pumpAndSettle();
  }

  /// Selects a widget to run evaluation on.
  Future<void> selectWidgetTreeNode(Finder finder) async {
    await tapAndPump(
      find.descendant(
        of: find.byKey(InspectorScreenBodyState.summaryTreeKey),
        matching: finder,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> takeSnapshot() async {
    await takeHeapSnapshot(tester);

    // Sort by class.
    await tapAndPump(find.text('Class'));

    // Select class.
    await tapAndPump(find.text('MyApp'));
  }

  Future<void> openContextMenuForClass(String className) async {
    await tapAndPump(find.text(className));
    await tapAndPump(
      find.descendant(
        of: find.byType(InstanceViewWithContextMenu),
        matching: find.byType(ContextMenuButton),
      ),
    );
  }
}

Future<void> testBasicEval(EvalTester tester) async {
  await tester.testEval('21 + 34', find.text('55'));
}

Future<void> testAssignment(EvalTester tester) async {
  await tester.testEval('DateTime(2023)', find.text('DateTime'));
  await tester.testEval(
    r'var x = $0',
    find.textContaining('Variable x is created '),
  );
  await tester.testEval(
    'x.toString()',
    find.text("'${DateTime(2023).toString()}'"),
  );
}
