// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/code_size/code_size_screen.dart';
import 'package:devtools_app/src/code_size/code_size_controller.dart';
import 'package:devtools_app/src/code_size/code_size_table.dart';
import 'package:devtools_app/src/split.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/wrappers.dart';

// TODO(peterdjlee): Clean up the tests once  we don't need loadFakeData.

void main() {
  CodeSizeScreen screen;
  CodeSizeController codeSizeController;

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
      codeSizeController = CodeSizeController();
      await codeSizeController.loadTree(
        '../devtools_testing/lib/support/treemap_test_data_v8_new.json',
      );
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithControllers(
        Builder(builder: screen.buildTab),
        codeSize: codeSizeController,
      ));
      expect(find.text('Code Size'), findsOneWidget);
    });

    testWidgetsWithWindowSize('builds initial content', windowSize,
        (WidgetTester tester) async {
      await pumpCodeSizeScreen(
        tester,
        codeSizeController: codeSizeController,
      );

      expect(codeSizeController.currentRoot.value, isNotNull);
      expect(find.byType(CodeSizeBody), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);

      expect(find.byKey(CodeSizeBodyState.snapshotTabKey), findsOneWidget);

      expect(find.byKey(CodeSizeBodyState.diffTabKey), findsOneWidget);

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
        codeSizeController: codeSizeController,
      );

      expect(find.byKey(CodeSizeBodyState.treemapKey), findsOneWidget);

      expect(
        find.byType(DropdownButtonHideUnderline),
        findsNothing,
      );

      // Assumes the treemap is built with treemap_test_data_v8_new.json
      expect(find.text('Root [6.0 MB]'), findsOneWidget);

      expect(find.byType(CodeSizeSnapshotTable), findsOneWidget);
      expect(find.byType(CodeSizeDiffTable), findsNothing);
    });

    testWidgetsWithWindowSize('builds diff tab', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await pumpCodeSizeScreen(
          tester,
          codeSizeController: codeSizeController,
        );
        await tester.tap(find.byKey(CodeSizeBodyState.diffTabKey));

        await codeSizeController.loadFakeDiffData(
          '../devtools_testing/lib/support/treemap_test_data_v8_old.json',
          '../devtools_testing/lib/support/treemap_test_data_v8_new.json',
          DiffTreeType.combined,
        );

        await tester.pumpAndSettle();

        expect(find.byKey(CodeSizeBodyState.treemapKey), findsOneWidget);

        expect(
          find.byType(DropdownButtonHideUnderline),
          findsOneWidget,
        );

        // Assumes the treemap is built with treemap_test_data_v8_new.json and treemap_test_data_v8_old.json
        expect(find.text('Root [+1.5 MB]'), findsOneWidget);

        expect(find.byType(CodeSizeSnapshotTable), findsNothing);
        expect(find.byType(CodeSizeDiffTable), findsOneWidget);
      });
    });
  });
}
