// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Do not delete these arguments. They are parsed by test runner.
// test-argument:appPath="test/test_infra/fixtures/memory_app"

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/memory/panes/control/primary_controls.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/widgets/snapshot_list.dart';
import 'package:devtools_app/src/screens/memory/shared/primitives/instance_context_menu.dart';
import 'package:devtools_app/src/shared/console/widgets/console_pane.dart';
import 'package:devtools_test/devtools_integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// To run:
// dart run integration_test/run_tests.dart --target=integration_test/test/live_connection/eval_and_browse_test.dart

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp testApp;

  setUpAll(() {
    testApp = TestApp.fromEnvironment();
    expect(testApp.vmServiceUri, isNotNull);
  });

  tearDown(() async {
    await resetHistory();
  });

  testWidgets('memory eval and browse', (tester) async {
    await pumpAndConnectDevTools(tester, testApp);

    final evalTester = _EvalAndBrowseTester(tester);
    await evalTester.prepareMemoryUI();

    logStatus('test basic evaluation');
    await _testBasicEval(evalTester);

    logStatus('test variable assignment');
    await _testAssignment(evalTester);

    logStatus('test dump one instance to console');
    await _profileOneInstance(evalTester);

    logStatus('test dump all instances to console');
    await _profileAllInstances(evalTester);

    logStatus('test take a snapshot');
    await evalTester.switchToSnapshotsAndTakeOne();

    logStatus('test inbound references are listed on console instance');
    await _inboundReferencesAreListed(evalTester);
  });
}

Future<void> _testBasicEval(_EvalAndBrowseTester tester) async {
  await tester.testEval('21 + 34', find.text('55'));
}

Future<void> _testAssignment(_EvalAndBrowseTester tester) async {
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

Future<void> _profileOneInstance(_EvalAndBrowseTester tester) async {
  await tester.openContextMenuForClass('MyHomePage');
  await tester.tapAndPump(
    find.textContaining('one instance'),
    duration: longPumpDuration,
  );
  expect(find.text('MyHomePage'), findsNWidgets(2));
}

Future<void> _profileAllInstances(_EvalAndBrowseTester tester) async {
  await tester.openContextMenuForClass('_MyHomePageState');
  await tester.tapAndPump(find.textContaining('all class instances'));
  await tester.tapAndPump(
    find.text('Direct instances'),
    duration: longPumpDuration,
  );

  expect(find.text('List (1 item)'), findsOneWidget);
}

Future<void> _inboundReferencesAreListed(_EvalAndBrowseTester tester) async {
  await tester.openContextMenuForClass('MyApp');

  await tester.tapAndPump(find.textContaining('one instance'));
  await tester.tapAndPump(find.text('Any'), duration: longPumpDuration);

  Finder? next = await tester.tapAndPump(
    find.textContaining('MyApp, retained size '),
    next: find.text('references'),
  );
  next = await tester.tapAndPump(
    next!,
    next: find.textContaining('static ('),
  );
  next = await tester.tapAndPump(
    next!,
    description: 'text containing "static ("',
    next: find.text('inbound'),
  );
  next = await tester.tapAndPump(
    next!,
    next: find.text('View'),
  );
}

class _EvalAndBrowseTester {
  _EvalAndBrowseTester(this.tester);

  final WidgetTester tester;

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

  /// Prepares the UI of the memory screen so that the eval-related elements are
  /// visible on the screen for testing.
  Future<void> prepareMemoryUI() async {
    // Open memory screen.
    await switchToScreen(
      tester,
      tabIcon: ScreenMetaData.memory.icon!,
      screenId: ScreenMetaData.memory.id,
    );

    // Close warning and chart to get screen space.
    await tapAndPump(
      find.descendant(
        of: find.byType(BannerWarning),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tapAndPump(find.text(PrimaryControls.memoryChartText));

    // Make console wider.
    // The distance is big enough to see more items in console,
    // but not too big to make classes in snapshot hidden.
    const dragDistance = -360.0;
    await tester.drag(
      find.byType(ConsolePaneHeader),
      const Offset(0, dragDistance),
    );
    await tester.pumpAndSettle();
  }

  Future<void> switchToSnapshotsAndTakeOne() async {
    // Switch to diff tab.
    await tapAndPump(find.text('Diff Snapshots'));

    logStatus('Started taking snapshot.');
    // Take snapshot.
    const snapshotDuration = Duration(seconds: 20);
    await tapAndPump(
      find.byIcon(iconToTakeSnapshot),
      duration: snapshotDuration,
    );
    logStatus('Finished taking snapshot.');

    // Sort by class.
    await tapAndPump(find.text('Class'));

    // Select class.
    await tapAndPump(find.text('MyApp'));
  }

  /// Taps and settles.
  ///
  /// If [next] is provided, will repeat the tap untill [next] returns results.
  /// If [next] is not null returns [next].
  Future<Finder?> tapAndPump(
    Finder finder, {
    Duration? duration,
    Finder? next,
    String? description,
  }) async {
    Future<void> action(int tryNumber) async {
      logStatus('\nattempt #$tryNumber, tapping');
      logStatus(description ?? finder.toString());
      tryNumber++;
      await tester.tap(finder);
      await tester.pump(duration);
      await tester.pumpAndSettle();
    }

    await action(0);

    if (next == null) return null;

    // These tries are needed because tap in console is flaky.
    for (var tryNumber = 1; tryNumber < 10; tryNumber++) {
      try {
        final items = tester.widgetList(next);
        if (items.isNotEmpty) return next;
        await action(tryNumber);
      } on StateError {
        // tester.widgetList throws StateError if no widgets found.
        await action(tryNumber);
      }
    }

    throw StateError('Could not find $next');
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
