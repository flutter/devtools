// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
      codeSizeController.loadFakeTree('new_v8');
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

      expect(codeSizeController.snapshotRoot.value, isNotNull);
      expect(find.byType(CodeSizeBody), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);

      expect(find.byKey(CodeSizeScreen.snapshotTabKey), findsOneWidget);
      expect(find.byKey(CodeSizeScreen.diffTabKey), findsOneWidget);

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

      expect(find.byKey(CodeSizeScreen.dropdownKey), findsNothing);
      expect(find.byKey(CodeSizeScreen.clearButtonKey), findsOneWidget);

      expect(find.byType(SnapshotView), findsOneWidget);
      expect(find.byKey(CodeSizeScreen.snapshotViewTreemapKey), findsOneWidget);

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
        await tester.tap(find.byKey(CodeSizeScreen.diffTabKey));

        codeSizeController.loadFakeDiffTree('old_v8', 'new_v8');

        await tester.pumpAndSettle();

        expect(find.byKey(CodeSizeScreen.dropdownKey), findsOneWidget);
        expect(find.byKey(CodeSizeScreen.clearButtonKey), findsOneWidget);

        expect(find.byType(DiffView), findsOneWidget);
        expect(
          find.byKey(CodeSizeScreen.snapshotViewTreemapKey),
          findsOneWidget,
        );
        // Assumes the treemap is built with treemap_test_data_v8_new.json and treemap_test_data_v8_old.json
        // const text = 'package:pointycastle [+465.8 KB]';
        // expect(find.text(text), findsOneWidget);
        // await tester.tap(find.text(text));
        // await tester.pumpAndSettle();

        // expect(find.text('ecc\n[+129.1 KB]'), findsOneWidget);
        // expect(find.text('dart:core'), findsNothing);

        expect(find.byType(CodeSizeSnapshotTable), findsNothing);
        expect(find.byType(CodeSizeDiffTable), findsOneWidget);
      });
    });
  });
}
