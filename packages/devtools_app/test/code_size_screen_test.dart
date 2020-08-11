// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/src/code_size/code_size_screen.dart';
import 'package:devtools_app/src/code_size/code_size_controller.dart';
import 'package:devtools_app/src/code_size/code_size_table.dart';
import 'package:devtools_app/src/code_size/file_import_container.dart';
import 'package:devtools_app/src/split.dart';
import 'package:devtools_app/src/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/code_size_test_data/new_v8.dart';
import 'support/code_size_test_data/old_v8.dart';
import 'support/wrappers.dart';

// TODO(peterdjlee): Clean up the tests once  we don't need loadFakeData.

void main() {
  final lastModifiedTime = DateTime.parse('2020-07-28 13:29:00');

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
    });

    final defaultData = DevToolsJsonFile(
      name: 'lib/src/code_size/stub_data/new_v8.dart',
      lastModifiedTime: lastModifiedTime,
      data: json.decode(newV8),
    );

    Future<void> loadDataAndPump(
      WidgetTester tester, {
      DevToolsJsonFile data,
    }) async {
      data ??= defaultData;
      codeSizeController.loadTreeFromJsonFile(data);
      await tester.pumpAndSettle();
    }

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

      expect(find.byType(CodeSizeBody), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);

      expect(find.byKey(CodeSizeScreen.snapshotTabKey), findsOneWidget);
      expect(find.byKey(CodeSizeScreen.diffTabKey), findsOneWidget);

      await loadDataAndPump(tester);

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

      expect(find.byType(FileImportContainer), findsOneWidget);
      expect(find.text(SnapshotView.importInstructions), findsOneWidget);
      expect(find.text('No File Selected'), findsOneWidget);

      await loadDataAndPump(tester);

      expect(find.byType(FileImportContainer), findsNothing);
      expect(find.text(SnapshotView.importInstructions), findsNothing);
      expect(find.text('No File Selected'), findsNothing);
      expect(find.byType(SnapshotView), findsOneWidget);
      expect(
        find.text(
          'Snapshot: lib/src/code_size/stub_data/new_v8.dart - 7/28/2020 1:29 PM',
        ),
        findsOneWidget,
      );
      expect(find.byKey(CodeSizeScreen.snapshotViewTreemapKey), findsOneWidget);

      // Assumes the treemap is built with treemap_test_data_v8_new.json
      expect(find.text('Root [6.0 MB]'), findsOneWidget);

      expect(find.byType(CodeSizeSnapshotTable), findsOneWidget);
      expect(find.byType(CodeSizeDiffTable), findsNothing);
    });

    testWidgetsWithWindowSize('builds diff tab', windowSize,
        (WidgetTester tester) async {
      await pumpCodeSizeScreen(
        tester,
        codeSizeController: codeSizeController,
      );
      await tester.tap(find.byKey(CodeSizeScreen.diffTabKey));
      await tester.pumpAndSettle();

      expect(find.byType(DualFileImportContainer), findsOneWidget);
      expect(find.byType(FileImportContainer), findsNWidgets(2));
      expect(find.text(DiffView.importOldInstructions), findsOneWidget);
      expect(find.text(DiffView.importNewInstructions), findsOneWidget);
      expect(find.text('No File Selected'), findsNWidgets(2));

      codeSizeController.loadDiffTreeFromJsonFiles(
        DevToolsJsonFile(
          name: 'lib/src/code_size/stub_data/old_v8.dart',
          lastModifiedTime: lastModifiedTime,
          data: json.decode(oldV8),
        ),
        DevToolsJsonFile(
          name: 'lib/src/code_size/stub_data/new_v8.dart',
          lastModifiedTime: lastModifiedTime,
          data: json.decode(newV8),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(CodeSizeScreen.dropdownKey), findsOneWidget);
      expect(find.byKey(CodeSizeScreen.clearButtonKey), findsOneWidget);

      expect(find.byType(DualFileImportContainer), findsNothing);
      expect(find.byType(FileImportContainer), findsNothing);
      expect(find.text(DiffView.importOldInstructions), findsNothing);
      expect(find.text(DiffView.importNewInstructions), findsNothing);
      expect(find.text('No File Selected'), findsNothing);
      expect(find.byType(DiffView), findsOneWidget);
      expect(
        find.text(
          'Diffing Snapshots: lib/src/code_size/stub_data/old_v8.dart - 7/28/2020 1:29 PM (OLD)    vs    (NEW) lib/src/code_size/stub_data/new_v8.dart - 7/28/2020 1:29 PM',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(CodeSizeScreen.snapshotViewTreemapKey),
        findsOneWidget,
      );

      // Assumes the treemap is built with treemap_test_data_v8_new.json and treemap_test_data_v8_old.json
//      const text = 'package:pointycastle [+465.8 KB]';
//      expect(find.text(text), findsOneWidget);
//      await tester.tap(find.text(text));
//      await tester.pumpAndSettle();
//
//      expect(find.text('ecc\n[+129.1 KB]'), findsOneWidget);
//      expect(find.text('dart:core'), findsNothing);

      expect(find.byType(CodeSizeSnapshotTable), findsNothing);
      expect(find.byType(CodeSizeDiffTable), findsOneWidget);
    });
  });
}
