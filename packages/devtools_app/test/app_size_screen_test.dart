// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/src/app_size/app_size_screen.dart';
import 'package:devtools_app/src/app_size/app_size_controller.dart';
import 'package:devtools_app/src/app_size/app_size_table.dart';
import 'package:devtools_app/src/app_size/file_import_container.dart';
import 'package:devtools_app/src/common_widgets.dart';
import 'package:devtools_app/src/notifications.dart';
import 'package:devtools_app/src/split.dart';
import 'package:devtools_app/src/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_size_test_controller.dart';
import 'support/app_size_test_data/new_v8.dart';
import 'support/app_size_test_data/old_v8.dart';
import 'support/app_size_test_data/sizes.dart';
import 'support/app_size_test_data/unsupported_file.dart';
import 'support/wrappers.dart';

void main() {
  final lastModifiedTime = DateTime.parse('2020-07-28 13:29:00');

  final oldV8JsonFile = DevToolsJsonFile(
    name: 'lib/src/app_size/stub_data/old_v8.dart',
    lastModifiedTime: lastModifiedTime,
    data: json.decode(oldV8),
  );

  final newV8JsonFile = DevToolsJsonFile(
    name: 'lib/src/app_size/stub_data/new_v8.dart',
    lastModifiedTime: lastModifiedTime,
    data: json.decode(newV8),
  );

  AppSizeScreen screen;
  AppSizeTestController appSizeController;

  const windowSize = Size(2560.0, 1338.0);

  Future<void> pumpAppSizeScreen(
    WidgetTester tester, {
    AppSizeTestController controller,
  }) async {
    await tester.pumpWidget(wrapWithControllers(
      const AppSizeBody(),
      appSize: controller,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(AppSizeBody), findsOneWidget);
  }

  Future<void> loadDataAndPump(
    WidgetTester tester, {
    DevToolsJsonFile data,
  }) async {
    data ??= newV8JsonFile;
    appSizeController.loadTreeFromJsonFile(
      jsonFile: data,
      onError: (error) => {},
    );
    await tester.pumpAndSettle();
  }

  group('AppSizeScreen', () {
    setUp(() async {
      screen = const AppSizeScreen();
      appSizeController = AppSizeTestController();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithControllers(
        Builder(builder: screen.buildTab),
        appSize: appSizeController,
      ));
      expect(find.text('App Size'), findsOneWidget);
    });

    testWidgetsWithWindowSize('builds initial content', windowSize,
        (WidgetTester tester) async {
      await pumpAppSizeScreen(
        tester,
        controller: appSizeController,
      );

      expect(find.byType(AppSizeBody), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);

      expect(find.byKey(AppSizeScreen.analysisTabKey), findsOneWidget);
      expect(find.byKey(AppSizeScreen.diffTabKey), findsOneWidget);

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
      screen = const AppSizeScreen();
      appSizeController = AppSizeTestController();
    });

    testWidgetsWithWindowSize('imports file and loads data', windowSize,
        (WidgetTester tester) async {
      await pumpAppSizeScreen(
        tester,
        controller: appSizeController,
      );

      expect(find.byKey(AppSizeScreen.dropdownKey), findsNothing);
      expect(find.byType(ClearButton), findsOneWidget);

      expect(find.byType(FileImportContainer), findsOneWidget);
      expect(find.text(AnalysisView.importInstructions), findsOneWidget);
      expect(find.text('No File Selected'), findsOneWidget);

      appSizeController.loadTreeFromJsonFile(
        jsonFile: newV8JsonFile,
        onError: (error) => {},
        delayed: true,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(AppSizeScreen.loadingMessage), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.byType(FileImportContainer), findsNothing);
      expect(find.text(AnalysisView.importInstructions), findsNothing);
      expect(find.text('No File Selected'), findsNothing);
      expect(find.byType(AnalysisView), findsOneWidget);
      expect(
        find.text(
          'Dart AOT snapshot: lib/src/app_size/stub_data/new_v8.dart - 7/28/2020 1:29 PM',
        ),
        findsOneWidget,
      );
      expect(find.byKey(AppSizeScreen.analysisViewTreemapKey), findsOneWidget);

      final List<Breadcrumb> breadcrumbs = tester
          .widgetList(find.byType(Breadcrumb))
          .map((widget) => widget as Breadcrumb)
          .toList();
      expect(breadcrumbs.length, 1);
      expect(breadcrumbs.first.text, equals('Root [6.0 MB]'));
      expect(find.byType(BreadcrumbNavigator), findsOneWidget);
      expect(find.text('package:flutter'), findsOneWidget);
      expect(find.text('dart:core'), findsOneWidget);

      expect(find.byType(AppSizeAnalysisTable), findsOneWidget);
      expect(find.byType(AppSizeDiffTable), findsNothing);
    });

    testWidgetsWithWindowSize('clears data', windowSize,
        (WidgetTester tester) async {
      await pumpAppSizeScreen(
        tester,
        controller: appSizeController,
      );

      await loadDataAndPump(tester);

      await tester.tap(find.byType(ClearButton));
      await tester.pumpAndSettle();

      expect(find.byType(FileImportContainer), findsOneWidget);
      expect(find.text(AnalysisView.importInstructions), findsOneWidget);
      expect(find.text('No File Selected'), findsOneWidget);
    });
  });

  group('DiffView', () {
    setUp(() async {
      screen = const AppSizeScreen();
      appSizeController = AppSizeTestController();
    });

    Future<void> loadDiffTabAndSettle(WidgetTester tester) async {
      await pumpAppSizeScreen(
        tester,
        controller: appSizeController,
      );
      await tester.tap(find.byKey(AppSizeScreen.diffTabKey));
      await tester.pumpAndSettle();
    }

    Future<void> loadDiffDataAndPump(
      WidgetTester tester,
      DevToolsJsonFile oldJsonFile,
      DevToolsJsonFile newJsonFile,
    ) async {
      appSizeController.loadDiffTreeFromJsonFiles(
        oldFile: oldJsonFile,
        newFile: newJsonFile,
        onError: (error) => {},
      );
      await tester.pumpAndSettle();
    }

    testWidgetsWithWindowSize('builds initial content', windowSize,
        (WidgetTester tester) async {
      await loadDiffTabAndSettle(tester);

      expect(find.byKey(AppSizeScreen.dropdownKey), findsOneWidget);
      expect(find.byType(ClearButton), findsOneWidget);

      expect(find.byType(DualFileImportContainer), findsOneWidget);
      expect(find.byType(FileImportContainer), findsNWidgets(2));
      expect(find.text(DiffView.importOldInstructions), findsOneWidget);
      expect(find.text(DiffView.importNewInstructions), findsOneWidget);
      expect(find.text('No File Selected'), findsNWidgets(2));
    });

    testWidgetsWithWindowSize('imports files and loads data', windowSize,
        (WidgetTester tester) async {
      await loadDiffTabAndSettle(tester);

      appSizeController.loadDiffTreeFromJsonFiles(
        oldFile: oldV8JsonFile,
        newFile: newV8JsonFile,
        onError: (error) => {},
        delayed: true,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(AppSizeScreen.loadingMessage), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.byType(FileImportContainer), findsNothing);
      expect(find.text(DiffView.importOldInstructions), findsNothing);
      expect(find.text(DiffView.importNewInstructions), findsNothing);
      expect(find.text('No File Selected'), findsNothing);

      expect(find.byType(DiffView), findsOneWidget);
      expect(
        find.text(
          'Diffing Dart AOT snapshots: lib/src/app_size/stub_data/old_v8.dart - 7/28/2020 1:29 PM (OLD)    vs    (NEW) lib/src/app_size/stub_data/new_v8.dart - 7/28/2020 1:29 PM',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(AppSizeScreen.diffViewTreemapKey),
        findsOneWidget,
      );
      expect(
        find.byKey(AppSizeScreen.analysisViewTreemapKey),
        findsNothing,
      );

      final List<Breadcrumb> breadcrumbs = tester
          .widgetList(find.byType(Breadcrumb))
          .map((widget) => widget as Breadcrumb)
          .toList();
      expect(breadcrumbs.length, 1);
      expect(breadcrumbs.first.text, equals('Root [+1.5 MB]'));
      expect(find.text('package:pointycastle'), findsOneWidget);
      expect(find.text('package:flutter'), findsOneWidget);

      expect(find.byType(AppSizeAnalysisTable), findsNothing);
      expect(find.byType(AppSizeDiffTable), findsOneWidget);
    });

    testWidgetsWithWindowSize(
        'loads data and shows different tree types', windowSize,
        (WidgetTester tester) async {
      await loadDiffTabAndSettle(tester);

      await loadDiffDataAndPump(tester, oldV8JsonFile, newV8JsonFile);

      await tester.tap(find.byKey(AppSizeScreen.dropdownKey));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Increase Only').hitTestable());
      await tester.pumpAndSettle();

      final List<Breadcrumb> breadcrumbs = tester
          .widgetList(find.byType(Breadcrumb))
          .map((widget) => widget as Breadcrumb)
          .toList();
      expect(breadcrumbs.length, 1);
      expect(breadcrumbs.first.text, equals('Root [+1.6 MB]'));
      expect(find.text('package:pointycastle'), findsOneWidget);
      expect(find.text('package:flutter'), findsOneWidget);

      await tester.tap(find.byKey(AppSizeScreen.dropdownKey));
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

      await tester.tap(find.byType(ClearButton));
      await tester.pumpAndSettle();

      expect(find.byType(DualFileImportContainer), findsOneWidget);
      expect(find.byType(FileImportContainer), findsNWidgets(2));
      expect(find.text(DiffView.importOldInstructions), findsOneWidget);
      expect(find.text(DiffView.importNewInstructions), findsOneWidget);
      expect(find.text('No File Selected'), findsNWidgets(2));
    });
  });

  group('AppSizeController', () {
    BuildContext buildContext;

    setUp(() async {
      screen = const AppSizeScreen();
      appSizeController = AppSizeTestController();
    });

    Future<void> pumpAppSizeScreenWithContext(
      WidgetTester tester, {
      AppSizeTestController controller,
    }) async {
      await tester.pumpWidget(wrapWithControllers(
        MaterialApp(
          builder: (context, child) => Notifications(child: child),
          home: Builder(
            builder: (context) {
              buildContext = context;
              return const AppSizeBody();
            },
          ),
        ),
        appSize: controller,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byType(AppSizeBody), findsOneWidget);
    }

    Future<void> loadDiffTreeAndPump(
      WidgetTester tester,
      String firstFile,
      String secondFile,
    ) async {
      appSizeController.loadDiffTreeFromJsonFiles(
        oldFile: DevToolsJsonFile(
          name: '',
          lastModifiedTime: lastModifiedTime,
          data: json.decode(firstFile),
        ),
        newFile: DevToolsJsonFile(
          name: '',
          lastModifiedTime: lastModifiedTime,
          data: json.decode(secondFile),
        ),
        onError: (error) => Notifications.of(buildContext).push(error),
      );
      await tester.pumpAndSettle();
    }

    testWidgetsWithWindowSize(
        'outputs error notifications for invalid input on the snapshot tab',
        windowSize, (WidgetTester tester) async {
      await pumpAppSizeScreenWithContext(
        tester,
        controller: appSizeController,
      );

      appSizeController.loadTreeFromJsonFile(
        jsonFile: DevToolsJsonFile(
          name: 'unsupported_file.json',
          lastModifiedTime: lastModifiedTime,
          data: unsupportedFile,
        ),
        onError: (error) => Notifications.of(buildContext).push(error),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(AppSizeController.unsupportedFileTypeError),
        findsOneWidget,
      );
    });

    testWidgetsWithWindowSize(
        'outputs error notifications for invalid input on the diff tab',
        windowSize, (WidgetTester tester) async {
      await pumpAppSizeScreenWithContext(
        tester,
        controller: appSizeController,
      );
      await tester.tap(find.byKey(AppSizeScreen.diffTabKey));
      await tester.pumpAndSettle();

      await loadDiffTreeAndPump(tester, newV8, newV8);
      expect(
        find.text(AppSizeController.identicalFilesError),
        findsOneWidget,
      );

      await loadDiffTreeAndPump(tester, instructionSizes, newV8);
      expect(
        find.text(AppSizeController.differentTypesError),
        findsOneWidget,
      );

      await loadDiffTreeAndPump(tester, unsupportedFile, unsupportedFile);
      expect(
        find.text(AppSizeController.unsupportedFileTypeError),
        findsOneWidget,
      );
    });
  });
}
