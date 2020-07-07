// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/code_size/code_size_screen.dart';
import 'package:devtools_app/src/code_size/code_size_controller.dart';
import 'package:devtools_app/src/split.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/wrappers.dart';

void main() {
  CodeSizeScreen screen;
  CodeSizeController snapshotTabController;

  Future<void> pumpCodeSizeScreen(
    WidgetTester tester, {
    CodeSizeController codeSizeController,
  }) async {
    await tester.pumpWidget(wrapWithControllers(
      const CodeSizeBody(),
      codeSize: codeSizeController,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(CodeSizeBody), findsOneWidget);
  }

  const windowSize = Size(2050.0, 1000.0);

  group('CodeSizeScreen', () {
    setUp(() async {
      screen = const CodeSizeScreen();
      snapshotTabController = CodeSizeController();
      await snapshotTabController.loadTree(
        '../devtools_testing/lib/support/treemap_test_data_v8_new.json',
      );
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithControllers(
        Builder(builder: screen.buildTab),
        codeSize: snapshotTabController,
      ));
      expect(find.text('Code Size'), findsOneWidget);
    });

    testWidgetsWithWindowSize('builds tabs', windowSize,
        (WidgetTester tester) async {
      await pumpCodeSizeScreen(
        tester,
        codeSizeController: snapshotTabController,
      );

      expect(snapshotTabController.currentRoot.value, isNotNull);
      expect(find.byType(CodeSizeBody), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);

      const snapshotTabKey = Key('Code Size Snapshot Tab');
      expect(find.byKey(snapshotTabKey), findsOneWidget);

      const diffTabKey = Key('Code Size Diff Tab');
      expect(find.byKey(diffTabKey), findsOneWidget);

      // Verify the state of the splitter.
      final splitFinder = find.byType(Split);
      expect(splitFinder, findsOneWidget);
      final Split splitter = tester.widget(splitFinder);
      expect(splitter.initialFractions[0], equals(0.67));
      expect(splitter.initialFractions[1], equals(0.33));
    });

    testWidgetsWithWindowSize('builds snapshot tab', windowSize,
        (WidgetTester tester) async {
      await pumpCodeSizeScreen(
        tester,
        codeSizeController: snapshotTabController,
      );

      const treemapKey = Key('Code Size Treemap');
      expect(find.byKey(treemapKey), findsOneWidget);

      const diffTreeTypeDropdownKey = Key('Code Size Diff Tree Type Dropdown');
      expect(find.byKey(diffTreeTypeDropdownKey), findsNothing);

      // Assumes the treemap is built with treemap_test_data_v8_old.json
      const text = 'Root [6.0 MB]';
      expect(find.text(text), findsOneWidget);

      const snapshotTableKey = Key('Code Size Snapshot Table');
      expect(find.byKey(snapshotTableKey), findsOneWidget);
      const diffTableKey = Key('Code Size Diff Table');
      expect(find.byKey(diffTableKey), findsNothing);
    });
  });
}
