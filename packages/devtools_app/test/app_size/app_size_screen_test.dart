// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/app_size/app_size_table.dart';
import 'package:devtools_app/src/shared/file_import.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_test_utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../test_infra/test_data/app_size/deferred_app.dart';
import '../test_infra/test_data/app_size/diff_deferred_app.dart';
import '../test_infra/test_data/app_size/diff_no_deferred_app.dart';
import '../test_infra/test_data/app_size/new_v8.dart';
import '../test_infra/test_data/app_size/old_v8.dart';
import '../test_infra/test_data/app_size/sizes.dart';
import '../test_infra/test_data/app_size/unsupported_file.dart';

void main() {
  setUp(() {
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());
  });

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

  final deferredAppFile = DevToolsJsonFile(
    name: 'lib/src/app_size/stub_data/deferred_app.dart',
    lastModifiedTime: lastModifiedTime,
    data: json.decode(deferredApp),
  );

  DevToolsJsonFile(
    name: 'lib/src/app_size/stub_data/diff_deferred_app.dart',
    lastModifiedTime: lastModifiedTime,
    data: json.decode(diffDeferredApp),
  );

  DevToolsJsonFile(
    name: 'lib/src/app_size/stub_data/diff_no_deferred_app.dart',
    lastModifiedTime: lastModifiedTime,
    data: json.decode(diffNonDeferredApp),
  );

  late AppSizeScreen screen;
  late AppSizeTestController appSizeController;
  FakeServiceConnectionManager fakeServiceConnection;

  const windowSize = Size(2560.0, 1338.0);

  Future<void> pumpAppSizeScreen(
    WidgetTester tester, {
    required AppSizeTestController controller,
  }) async {
    await tester.pumpWidget(
      wrapWithControllers(
        const AppSizeBody(),
        appSize: controller,
      ),
    );
    deferredLoadingSupportEnabled = true;
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(AppSizeBody), findsOneWidget);
  }

  Future<void> loadDataAndPump(
    WidgetTester tester, {
    DevToolsJsonFile? data,
  }) async {
    data ??= newV8JsonFile;
    appSizeController.loadTreeFromJsonFile(
      jsonFile: data,
      onError: (error) => {},
    );
    await tester.pumpAndSettle();
  }

  group('AppSizeScreen', () {
    setUp(() {
      screen = AppSizeScreen();
      appSizeController = AppSizeTestController();
      fakeServiceConnection = FakeServiceConnectionManager();
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      when(
        fakeServiceConnection.errorBadgeManager.errorCountNotifier('app-size'),
      ).thenReturn(ValueNotifier<int>(0));
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithControllers(
          Builder(builder: screen.buildTab),
          appSize: appSizeController,
        ),
      );
      expect(find.text('App Size'), findsOneWidget);
    });

    testWidgetsWithWindowSize(
      'builds initial content',
      windowSize,
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
        final splitFinder = find.byType(SplitPane);
        expect(splitFinder, findsOneWidget);
        final SplitPane splitter = tester.widget(splitFinder);
        expect(splitter.initialFractions[0], equals(0.67));
        expect(splitter.initialFractions[1], equals(0.33));
      },
    );

    testWidgetsWithWindowSize(
      'builds deferred content',
      windowSize,
      (WidgetTester tester) async {
        await pumpAppSizeScreen(
          tester,
          controller: appSizeController,
        );
        await loadDataAndPump(tester, data: deferredAppFile);

        // Verify the dropdown for selecting app units exists.
        final appUnitDropdownFinder = _findDropdownButton<AppUnit>();
        expect(appUnitDropdownFinder, findsOneWidget);

        // Verify the entire app is shown.
        final breadcrumbs = _fetchBreadcrumbs(tester);
        expect(breadcrumbs.length, 1);
        expect(breadcrumbs.first.text, equals('Entire App [39.8 MB]'));
        expect(find.richText('Main [39.5 MB]'), findsOneWidget);

        // Open the dropdown.
        await tester.tap(appUnitDropdownFinder);
        await tester.pumpAndSettle();

        // Verify the menu items in the dropdown are expected.
        final entireAppMenuItemFinder =
            _findMenuItemWithText<AppUnit>('Entire App');
        expect(entireAppMenuItemFinder, findsOneWidget);
        final mainMenuItemFinder = _findMenuItemWithText<AppUnit>('Main');
        expect(mainMenuItemFinder, findsOneWidget);
        final deferredMenuItemFinder =
            _findMenuItemWithText<AppUnit>('Deferred');
        expect(deferredMenuItemFinder, findsOneWidget);

        // Select the main unit.
        await tester.tap(find.text('Main').hitTestable());
        await tester.pumpAndSettle();

        // Verify the main unit is shown.
        final mainBreadcrumbs = _fetchBreadcrumbs(tester);
        expect(mainBreadcrumbs.length, 1);
        expect(mainBreadcrumbs.first.text, equals('Main [39.5 MB]'));
        expect(find.richText('appsize_app.app [39.5 MB]'), findsOneWidget);

        // Open the dropdown.
        await tester.tap(appUnitDropdownFinder);
        await tester.pumpAndSettle();

        // Select the deferred units.
        await tester.tap(find.text('Deferred').hitTestable());
        await tester.pumpAndSettle();

        // Verify the deferred units are shown.
        final deferredBreadcrumbs = _fetchBreadcrumbs(tester);
        expect(deferredBreadcrumbs.length, 1);
        expect(deferredBreadcrumbs.first.text, equals('Deferred [344.3 KB]'));
        expect(
          find.richText('flutter_assets [344.3 KB] (Deferred)'),
          findsOneWidget,
        );
      },
    );
  });

  group('SnapshotView', () {
    setUp(() {
      screen = AppSizeScreen();
      appSizeController = AppSizeTestController();
    });

    testWidgetsWithWindowSize(
      'imports file and loads data',
      windowSize,
      (WidgetTester tester) async {
        await pumpAppSizeScreen(
          tester,
          controller: appSizeController,
        );

        expect(find.byKey(AppSizeScreen.diffTypeDropdownKey), findsNothing);
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
            'Dart AOT snapshot: lib/src/app_size/stub_data/new_v8.dart - 7/28/2020 1:29 PM',
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(AppSizeScreen.analysisViewTreemapKey),
          findsOneWidget,
        );

        final breadcrumbs = _fetchBreadcrumbs(tester);
        expect(breadcrumbs.length, 1);
        expect(breadcrumbs.first.text, equals('Root [6.0 MB]'));
        expect(find.byType(BreadcrumbNavigator), findsOneWidget);

        expect(find.richText('package:flutter'), findsOneWidget);
        expect(find.richText('dart:core'), findsOneWidget);

        expect(find.byType(AppSizeAnalysisTable), findsOneWidget);
        expect(find.byType(AppSizeDiffTable), findsNothing);
      },
    );

    testWidgetsWithWindowSize(
      'clears data',
      windowSize,
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
      },
    );
  });

  group('DiffView', () {
    setUp(() {
      screen = AppSizeScreen();
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

    testWidgetsWithWindowSize(
      'builds initial content',
      windowSize,
      (WidgetTester tester) async {
        await loadDiffTabAndSettle(tester);

        expect(find.byKey(AppSizeScreen.diffTypeDropdownKey), findsOneWidget);
        expect(find.byKey(AppSizeScreen.appUnitDropdownKey), findsNothing);
        expect(find.byType(ClearButton), findsOneWidget);

        expect(find.byType(DualFileImportContainer), findsOneWidget);
        expect(find.byType(FileImportContainer), findsNWidgets(2));
        expect(find.text(DiffView.importOldInstructions), findsOneWidget);
        expect(find.text(DiffView.importNewInstructions), findsOneWidget);
        expect(find.text('No File Selected'), findsNWidgets(2));
      },
    );

    testWidgetsWithWindowSize(
      'imports files and loads data',
      windowSize,
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
            'Diffing Dart AOT snapshots: lib/src/app_size/stub_data/old_v8.dart - 7/28/2020 1:29 PM (OLD)    vs    (NEW) lib/src/app_size/stub_data/new_v8.dart - 7/28/2020 1:29 PM',
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

        final breadcrumbs = _fetchBreadcrumbs(tester);
        expect(breadcrumbs.length, 1);
        expect(breadcrumbs.first.text, equals('Root [+1.5 MB]'));
        expect(find.richText('package:pointycastle'), findsOneWidget);
        expect(find.richText('package:flutter'), findsOneWidget);

        expect(find.byType(AppSizeAnalysisTable), findsNothing);
        expect(find.byType(AppSizeDiffTable), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'loads data and shows different tree types',
      windowSize,
      (WidgetTester tester) async {
        await loadDiffTabAndSettle(tester);

        await loadDiffDataAndPump(tester, oldV8JsonFile, newV8JsonFile);

        await tester.tap(find.byKey(AppSizeScreen.diffTypeDropdownKey));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Increase Only').hitTestable());
        await tester.pumpAndSettle();

        final breadcrumbs = _fetchBreadcrumbs(tester);
        expect(breadcrumbs.length, 1);
        expect(breadcrumbs.first.text, equals('Root [+1.6 MB]'));

        expect(find.richText('package:pointycastle'), findsOneWidget);
        expect(find.richText('package:flutter'), findsOneWidget);

        await tester.tap(find.byKey(AppSizeScreen.diffTypeDropdownKey));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Decrease Only').hitTestable());
        await tester.pumpAndSettle();

        expect(find.richText('Root'), findsOneWidget);
        expect(find.richText('package:memory'), findsOneWidget);
        expect(find.richText('package:flutter'), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'clears data',
      windowSize,
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
      },
    );
  });

  group('AppSizeController', () {
    setUp(() {
      screen = AppSizeScreen();
      appSizeController = AppSizeTestController();
    });

    Future<void> pumpAppSizeScreenWithContext(
      WidgetTester tester, {
      required AppSizeTestController controller,
    }) async {
      await tester.pumpWidget(
        wrapWithControllers(
          MaterialApp(
            builder: (context, child) => child!,
            home: Builder(
              builder: (context) {
                return const AppSizeBody();
              },
            ),
          ),
          appSize: controller,
        ),
      );
      deferredLoadingSupportEnabled = true;
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
        onError: (error) => notificationService.push(error),
      );
      await tester.pumpAndSettle();
    }

    testWidgetsWithWindowSize(
      'outputs error notifications for invalid input on the snapshot tab',
      windowSize,
      (WidgetTester tester) async {
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
          onError: (error) => notificationService.push(error),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(AppSizeController.unsupportedFileTypeError),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithWindowSize(
      'outputs error notifications for invalid input on the diff tab',
      windowSize,
      (WidgetTester tester) async {
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
      },
    );

    testWidgetsWithWindowSize(
      'builds deferred content for diff table',
      windowSize,
      (WidgetTester tester) async {
        await pumpAppSizeScreen(
          tester,
          controller: appSizeController,
        );
        await tester.tap(find.byKey(AppSizeScreen.diffTabKey));
        await tester.pumpAndSettle();

        await loadDiffTreeAndPump(tester, diffNonDeferredApp, diffDeferredApp);

        // Verify the dropdown for selecting app units exists.
        final appUnitDropdownFinder = _findDropdownButton<AppUnit>();
        expect(appUnitDropdownFinder, findsOneWidget);

        // Open the app unit dropdown.
        await tester.tap(appUnitDropdownFinder);
        await tester.pumpAndSettle();

        // Verify the menu items in the dropdown are expected.
        final entireAppMenuItemFinder =
            _findMenuItemWithText<AppUnit>('Entire App');
        expect(entireAppMenuItemFinder, findsOneWidget);
        final mainMenuItemFinder = _findMenuItemWithText<AppUnit>('Main');
        expect(mainMenuItemFinder, findsOneWidget);
        final deferredMenuItemFinder =
            _findMenuItemWithText<AppUnit>('Deferred');
        expect(deferredMenuItemFinder, findsOneWidget);

        // Select the main unit.
        await tester.tap(find.richText('Main').hitTestable());
        await tester.pumpAndSettle();

        // Verify the main unit is shown for entire app.
        final mainBreadcrumbs = _fetchBreadcrumbs(tester);
        expect(mainBreadcrumbs.length, 1);
        expect(
          mainBreadcrumbs.first.text,
          equals(
            '/Main/appsize_app.app/Contents/Frameworks/App.framework/Resources/flutter_assets [-344.3 KB]',
          ),
        );
        expect(
          find.richText('packages/cupertino_icons/assets [-276.8 KB]'),
          findsOneWidget,
        );

        // Open the diffType dropdown.
        await tester.tap(find.byKey(AppSizeScreen.diffTypeDropdownKey));
        await tester.pumpAndSettle();

        // Select increase only.
        await tester.tap(find.text('Increase Only').hitTestable());
        await tester.pumpAndSettle();

        // Verify the main unit is shown for increase only.
        final mainIncreaseBreadcrumbs = _fetchBreadcrumbs(tester);
        expect(mainIncreaseBreadcrumbs.length, 1);
        expect(
          mainIncreaseBreadcrumbs.first.text,
          equals(
            '/Main/appsize_app.app/Contents/Frameworks/App.framework/Resources/flutter_assets [0 B]',
          ),
        );

        // Open the diffType dropdown.
        await tester.tap(find.byKey(AppSizeScreen.diffTypeDropdownKey));
        await tester.pumpAndSettle();

        // Select decrease only.
        await tester.tap(find.text('Decrease Only').hitTestable());
        await tester.pumpAndSettle();

        // Verify the main unit is shown for decrease only.
        final mainDecreaseBreadcrumbs = _fetchBreadcrumbs(tester);
        expect(mainDecreaseBreadcrumbs.length, 1);
        expect(
          mainDecreaseBreadcrumbs.first.text,
          equals(
            '/Main/appsize_app.app/Contents/Frameworks/App.framework/Resources/flutter_assets [-344.3 KB]',
          ),
        );
        expect(
          find.richText('packages/cupertino_icons/assets [-276.8 KB]'),
          findsOneWidget,
        );

        // Open the diffType dropdown.
        await tester.tap(find.byKey(AppSizeScreen.diffTypeDropdownKey));
        await tester.pumpAndSettle();

        // Select entire app.
        await tester.tap(find.text('Combined').hitTestable());
        await tester.pumpAndSettle();

        // Open the app unit dropdown.
        await tester.tap(appUnitDropdownFinder);
        await tester.pumpAndSettle();

        // Select the deferred units.
        await tester.tap(find.text('Deferred').hitTestable());
        await tester.pumpAndSettle();

        // Verify the deferred units are shown for entire app.
        final deferredBreadcrumbs = _fetchBreadcrumbs(tester);
        expect(deferredBreadcrumbs.length, 1);
        expect(
          deferredBreadcrumbs.first.text,
          equals('/Deferred/flutter_assets [+344.3 KB]'),
        );
        expect(
          find.richText('packages/cupertino_icons/assets [+276.8 KB]'),
          findsOneWidget,
        );

        // Open the diffType dropdown.
        await tester.tap(find.byKey(AppSizeScreen.diffTypeDropdownKey));
        await tester.pumpAndSettle();

        // Select increase only.
        await tester.tap(find.text('Increase Only').hitTestable());
        await tester.pumpAndSettle();

        // Verify the deferred unit is shown for increase only.
        final deferredIncreaseBreadcrumbs = _fetchBreadcrumbs(tester);
        expect(deferredIncreaseBreadcrumbs.length, 1);
        expect(
          deferredIncreaseBreadcrumbs.first.text,
          equals(
            '/Deferred/flutter_assets [+344.3 KB]',
          ),
        );
        expect(
          find.richText('packages/cupertino_icons/assets [+276.8 KB]'),
          findsOneWidget,
        );

        // Open the diffType dropdown.
        await tester.tap(find.byKey(AppSizeScreen.diffTypeDropdownKey));
        await tester.pumpAndSettle();

        // Select decrease only.
        await tester.tap(find.text('Decrease Only').hitTestable());
        await tester.pumpAndSettle();

        // Verify the main unit is shown for decrease only.
        final deferredDecreaseBreadcrumbs = _fetchBreadcrumbs(tester);
        expect(deferredDecreaseBreadcrumbs.length, 1);
        expect(
          deferredDecreaseBreadcrumbs.first.text,
          equals(
            '/Deferred/flutter_assets [0 B]',
          ),
        );
      },
    );
  });
}

class AppSizeTestController extends AppSizeController {
  @override
  void loadTreeFromJsonFile({
    required DevToolsJsonFile jsonFile,
    required void Function(String error) onError,
    bool delayed = false,
  }) async {
    if (delayed) {
      await delay();
    }
    super.loadTreeFromJsonFile(jsonFile: jsonFile, onError: onError);
  }

  @override
  void loadDiffTreeFromJsonFiles({
    required DevToolsJsonFile oldFile,
    required DevToolsJsonFile newFile,
    required void Function(String error) onError,
    bool delayed = false,
  }) async {
    if (delayed) {
      await delay();
    }
    super.loadDiffTreeFromJsonFiles(
      oldFile: oldFile,
      newFile: newFile,
      onError: onError,
    );
  }
}

List<Breadcrumb> _fetchBreadcrumbs(WidgetTester tester) {
  return tester
      .widgetList(find.byType(Breadcrumb))
      .map((widget) => widget as Breadcrumb)
      .toList();
}

Finder _findDropdownButton<T>() {
  return find.byType(DropdownButton<T>);
}

Finder _findMenuItemWithText<T>(String text) {
  return find.descendant(
    of: find.byType(DropdownMenuItem<T>),
    matching: find.richText(text).hitTestable(),
  );
}
