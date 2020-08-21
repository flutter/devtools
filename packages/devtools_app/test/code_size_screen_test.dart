// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/src/code_size/code_size_screen.dart';
import 'package:devtools_app/src/code_size/code_size_controller.dart';
import 'package:devtools_app/src/code_size/code_size_table.dart';
import 'package:devtools_app/src/code_size/file_import_container.dart';
import 'package:devtools_app/src/notifications.dart';
import 'package:devtools_app/src/split.dart';
import 'package:devtools_app/src/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/code_size_test_controller.dart';
import 'support/code_size_test_data/new_v8.dart';
import 'support/code_size_test_data/old_v8.dart';
import 'support/code_size_test_data/sizes.dart';
import 'support/code_size_test_data/unsupported_file.dart';
import 'support/wrappers.dart';

void main() {
  final lastModifiedTime = DateTime.parse('2020-07-28 13:29:00');

  final oldV8JsonFile = DevToolsJsonFile(
    name: 'lib/src/code_size/stub_data/old_v8.dart',
    lastModifiedTime: lastModifiedTime,
    data: json.decode(oldV8),
  );

  final newV8JsonFile = DevToolsJsonFile(
    name: 'lib/src/code_size/stub_data/new_v8.dart',
    lastModifiedTime: lastModifiedTime,
    data: json.decode(newV8),
  );

  CodeSizeScreen screen;
  CodeSizeTestController codeSizeController;

  const windowSize = Size(2560.0, 1338.0);

  Future<void> pumpCodeSizeScreen(
    WidgetTester tester, {
    CodeSizeTestController codeSizeController,
  }) async {
    await tester.pumpWidget(wrapWithControllers(
      const CodeSizeBody(),
      codeSize: codeSizeController,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(CodeSizeBody), findsOneWidget);
  }

  Future<void> loadDataAndPump(
    WidgetTester tester, {
    DevToolsJsonFile data,
  }) async {
    data ??= newV8JsonFile;
    codeSizeController.loadTreeFromJsonFile(data, (error) => {});
    await tester.pumpAndSettle();
  }

  group('CodeSizeScreen', () {
    setUp(() async {
      screen = const CodeSizeScreen();
      codeSizeController = CodeSizeTestController();
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
  });

  group('SnapshotView', () {
    setUp(() async {
      screen = const CodeSizeScreen();
      codeSizeController = CodeSizeTestController();
    });

    testWidgetsWithWindowSize('imports file and loads data', windowSize,
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

      codeSizeController.loadTreeFromJsonFile(
        newV8JsonFile,
        (error) => {},
        delayed: true,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(CodeSizeScreen.loadingMessage), findsOneWidget);
      await tester.pumpAndSettle();

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

      expect(find.text('Root [6.0 MB]'), findsOneWidget);
      expect(find.text('package:flutter'), findsOneWidget);
      expect(find.text('dart:core'), findsOneWidget);

      expect(find.byType(CodeSizeSnapshotTable), findsOneWidget);
      expect(find.byType(CodeSizeDiffTable), findsNothing);
    });

    testWidgetsWithWindowSize('clears data', windowSize,
        (WidgetTester tester) async {
      await pumpCodeSizeScreen(
        tester,
        codeSizeController: codeSizeController,
      );

      await loadDataAndPump(tester);

      await tester.tap(find.byKey(CodeSizeScreen.clearButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(FileImportContainer), findsOneWidget);
      expect(find.text(SnapshotView.importInstructions), findsOneWidget);
      expect(find.text('No File Selected'), findsOneWidget);
    });
  });

  group('DiffView', () {
    setUp(() async {
      screen = const CodeSizeScreen();
      codeSizeController = CodeSizeTestController();
    });

    Future<void> loadDiffTabAndSettle(WidgetTester tester) async {
      await pumpCodeSizeScreen(
        tester,
        codeSizeController: codeSizeController,
      );
      await tester.tap(find.byKey(CodeSizeScreen.diffTabKey));
      await tester.pumpAndSettle();
    }

    Future<void> loadDiffDataAndPump(
      WidgetTester tester,
      DevToolsJsonFile oldJsonFile,
      DevToolsJsonFile newJsonFile,
    ) async {
      codeSizeController.loadDiffTreeFromJsonFiles(
        oldJsonFile,
        newJsonFile,
        (error) => {},
      );
      await tester.pumpAndSettle();
    }

    testWidgetsWithWindowSize('builds initial content', windowSize,
        (WidgetTester tester) async {
      await loadDiffTabAndSettle(tester);

      expect(find.byKey(CodeSizeScreen.dropdownKey), findsOneWidget);
      expect(find.byKey(CodeSizeScreen.clearButtonKey), findsOneWidget);

      expect(find.byType(DualFileImportContainer), findsOneWidget);
      expect(find.byType(FileImportContainer), findsNWidgets(2));
      expect(find.text(DiffView.importOldInstructions), findsOneWidget);
      expect(find.text(DiffView.importNewInstructions), findsOneWidget);
      expect(find.text('No File Selected'), findsNWidgets(2));
    });

    testWidgetsWithWindowSize('imports files and loads data', windowSize,
        (WidgetTester tester) async {
      await loadDiffTabAndSettle(tester);

      codeSizeController.loadDiffTreeFromJsonFiles(
        oldV8JsonFile,
        newV8JsonFile,
        (error) => {},
        delayed: true,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(CodeSizeScreen.loadingMessage), findsOneWidget);
      await tester.pumpAndSettle();

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
        find.byKey(CodeSizeScreen.diffViewTreemapKey),
        findsOneWidget,
      );
      expect(
        find.byKey(CodeSizeScreen.snapshotViewTreemapKey),
        findsNothing,
      );

      expect(find.text('Root [+1.5 MB]'), findsOneWidget);
      expect(find.text('package:pointycastle'), findsOneWidget);
      expect(find.text('package:flutter'), findsOneWidget);

      expect(find.byType(CodeSizeSnapshotTable), findsNothing);
      expect(find.byType(CodeSizeDiffTable), findsOneWidget);
    });

    testWidgetsWithWindowSize(
        'loads data and shows different tree types', windowSize,
        (WidgetTester tester) async {
      await loadDiffTabAndSettle(tester);

      await loadDiffDataAndPump(tester, oldV8JsonFile, newV8JsonFile);

      await tester.tap(find.byKey(CodeSizeScreen.dropdownKey));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Increase Only').hitTestable());
      await tester.pumpAndSettle();

      expect(find.text('Root [+1.6 MB]'), findsOneWidget);
      expect(find.text('package:pointycastle'), findsOneWidget);
      expect(find.text('package:flutter'), findsOneWidget);

      await tester.tap(find.byKey(CodeSizeScreen.dropdownKey));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Decrease Only').hitTestable());
      await tester.pumpAndSettle();

      expect(find.text('Root'), findsOneWidget);
      expect(find.text('package:memory'), findsOneWidget);
      expect(find.text('package:flutter'), findsOneWidget);
    });

    testWidgetsWithWindowSize('clears data', windowSize,
        (WidgetTester tester) async {
      await loadDiffTabAndSettle(tester);

      await loadDiffDataAndPump(tester, oldV8JsonFile, newV8JsonFile);

      await tester.tap(find.byKey(CodeSizeScreen.clearButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(DualFileImportContainer), findsOneWidget);
      expect(find.byType(FileImportContainer), findsNWidgets(2));
      expect(find.text(DiffView.importOldInstructions), findsOneWidget);
      expect(find.text(DiffView.importNewInstructions), findsOneWidget);
      expect(find.text('No File Selected'), findsNWidgets(2));
    });
  });

  group('CodeSizeController', () {
    BuildContext buildContext;

    setUp(() async {
      screen = const CodeSizeScreen();
      codeSizeController = CodeSizeTestController();
    });

    Future<void> pumpCodeSizeScreenWithContext(
      WidgetTester tester, {
      CodeSizeTestController codeSizeController,
    }) async {
      await tester.pumpWidget(wrapWithControllers(
        MaterialApp(
          builder: (context, child) => Notifications(child: child),
          home: Builder(
            builder: (context) {
              buildContext = context;
              return const CodeSizeBody();
            },
          ),
        ),
        codeSize: codeSizeController,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byType(CodeSizeBody), findsOneWidget);
    }

    Future<void> loadDiffTreeAndPump(
      WidgetTester tester,
      String firstFile,
      String secondFile,
    ) async {
      codeSizeController.loadDiffTreeFromJsonFiles(
        DevToolsJsonFile(
          name: '',
          lastModifiedTime: lastModifiedTime,
          data: json.decode(firstFile),
        ),
        DevToolsJsonFile(
          name: '',
          lastModifiedTime: lastModifiedTime,
          data: json.decode(secondFile),
        ),
        (error) => Notifications.of(buildContext).push(error),
      );
      await tester.pumpAndSettle();
    }

    testWidgetsWithWindowSize(
        'outputs error notifications for invalid input on the snapshot tab',
        windowSize, (WidgetTester tester) async {
      await pumpCodeSizeScreenWithContext(
        tester,
        codeSizeController: codeSizeController,
      );

      codeSizeController.loadTreeFromJsonFile(
        DevToolsJsonFile(
          name: 'unsupported_file.json',
          lastModifiedTime: lastModifiedTime,
          data: unsupportedFile,
        ),
        (error) => Notifications.of(buildContext).push(error),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(CodeSizeController.unsupportedFileTypeError),
        findsOneWidget,
      );
    });

    testWidgetsWithWindowSize(
        'outputs error notifications for invalid input on the diff tab',
        windowSize, (WidgetTester tester) async {
      await pumpCodeSizeScreenWithContext(
        tester,
        codeSizeController: codeSizeController,
      );
      await tester.tap(find.byKey(CodeSizeScreen.diffTabKey));
      await tester.pumpAndSettle();

      await loadDiffTreeAndPump(tester, newV8, newV8);
      expect(
        find.text(CodeSizeController.identicalFilesError),
        findsOneWidget,
      );

      await loadDiffTreeAndPump(tester, instructionSizes, newV8);
      expect(
        find.text(CodeSizeController.differentTypesError),
        findsOneWidget,
      );

      await loadDiffTreeAndPump(tester, unsupportedFile, unsupportedFile);
      expect(
        find.text(CodeSizeController.unsupportedFileTypeError),
        findsOneWidget,
      );
    });
  });
}
