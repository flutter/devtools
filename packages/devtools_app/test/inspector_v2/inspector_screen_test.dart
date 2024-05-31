// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Fake construction requires number of unawaited calls.
// ignore_for_file: discarded_futures

import 'dart:convert';

import 'package:devtools_app/devtools_app.dart'
    hide
        InspectorController,
        InspectorScreen,
        InspectorTreeController,
        InspectorScreenBody,
        ErrorNavigator,
        FlutterInspectorSettingsDialog;
import 'package:devtools_app/src/screens/inspector_v2/inspector_controller.dart';
import 'package:devtools_app/src/screens/inspector_v2/inspector_screen.dart';
import 'package:devtools_app/src/screens/inspector_v2/inspector_tree_controller.dart';
import 'package:devtools_app/src/screens/inspector_v2/layout_explorer/flex/flex.dart';
import 'package:devtools_app/src/screens/inspector_v2/layout_explorer/layout_explorer.dart';
import 'package:devtools_app/src/service/service_extensions.dart' as extensions;
import 'package:devtools_app/src/shared/feature_flags.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:mockito/mockito.dart';

import '../test_infra/flutter_test_storage.dart';

void main() {
  final screen = InspectorScreen();

  late FakeServiceConnectionManager fakeServiceConnection;
  late FakeServiceExtensionManager fakeExtensionManager;
  late InspectorController inspectorController;
  const windowSize = Size(2600.0, 1200.0);

  final debuggerController = createMockDebuggerControllerWithDefaults();

  Widget buildInspectorScreen() {
    return wrapWithControllers(
      Builder(builder: screen.build),
      debugger: debuggerController,
      inspectorV2: inspectorController,
    );
  }

  setUp(() {
    setEnableExperiments();
    fakeServiceConnection = FakeServiceConnectionManager();
    fakeExtensionManager =
        fakeServiceConnection.serviceManager.serviceExtensionManager;
    mockConnectedApp(
      fakeServiceConnection.serviceManager.connectedApp!,
      isFlutterApp: true,
      isProfileBuild: false,
      isWebApp: false,
    );
    when(
      fakeServiceConnection.errorBadgeManager.errorCountNotifier('inspector'),
    ).thenReturn(ValueNotifier<int>(0));

    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(ServiceConnectionManager, fakeServiceConnection);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(Storage, FlutterTestStorage());
    setGlobal(NotificationService, NotificationService());
    fakeServiceConnection.consoleService.ensureServiceInitialized();

    inspectorController = InspectorController(
      inspectorTree: InspectorTreeController(),
      detailsTree: InspectorTreeController(),
      treeType: FlutterTreeType.widget,
    )..firstInspectorTreeLoadCompleted = true;
  });

  Future<void> mockExtensions() async {
    fakeExtensionManager.extensionValueOnDevice = {
      extensions.toggleSelectWidgetMode.extension: true,
      extensions.enableOnDeviceInspector.extension: true,
      extensions.toggleOnDeviceWidgetInspector.extension: true,
      extensions.debugPaint.extension: false,
    };
    await fakeExtensionManager.fakeAddServiceExtension(
      extensions.toggleOnDeviceWidgetInspector.extension,
    );
    await fakeExtensionManager
        .fakeAddServiceExtension(extensions.toggleSelectWidgetMode.extension);
    await fakeExtensionManager
        .fakeAddServiceExtension(extensions.enableOnDeviceInspector.extension);
    await fakeExtensionManager
        .fakeAddServiceExtension(extensions.debugPaint.extension);
    await fakeExtensionManager.fakeFrame();
  }

  void mockNoExtensionsAvailable() {
    fakeExtensionManager.extensionValueOnDevice = {
      extensions.toggleOnDeviceWidgetInspector.extension: true,
      extensions.toggleSelectWidgetMode.extension: false,
      extensions.debugPaint.extension: false,
    };
    // Don't actually send any events to the client indicating that service
    // extensions are avaiable.
    fakeExtensionManager.fakeFrame();
  }

  testWidgetsWithWindowSize(
    'builds its tab',
    windowSize,
    (WidgetTester tester) async {
      await tester.pumpWidget(buildInspectorScreen());
      await tester.pumpAndSettle();
      expect(find.byType(InspectorScreenBody), findsOneWidget);
    },
  );

  group('Widget Errors', () {
    // Display of error navigator/indicators is tested by a golden in
    // inspector_integration_test.dart

    testWidgetsWithWindowSize(
      'does not render error navigator if no errors',
      windowSize,
      (WidgetTester tester) async {
        await tester.pumpWidget(buildInspectorScreen());
        expect(find.byType(ErrorNavigator), findsNothing);
      },
    );
  });

  testWidgetsWithWindowSize(
    'builds with no data',
    windowSize,
    (WidgetTester tester) async {
      // Make sure the window is wide enough to display description text.

      await tester.pumpWidget(buildInspectorScreen());
      expect(find.byType(InspectorScreenBody), findsOneWidget);
      expect(find.byTooltip('Refresh Tree'), findsOneWidget);
      expect(find.text(extensions.debugPaint.title), findsOneWidget);
      // Make sure there is not an overflow if the window is narrow.
      // TODO(jacobr): determine why there are overflows in the test environment
      // but not on the actual device for this cae.
      // await setWindowSize(const Size(1000.0, 1200.0));
      // Verify that description text is no-longer shown.
      // expect(find.text(extensions.debugPaint.description), findsOneWidget);
    },
  );

  testWidgetsWithWindowSize(
    'Test toggling service extension buttons',
    windowSize,
    (WidgetTester tester) async {
      await mockExtensions();
      expect(
        fakeExtensionManager
            .extensionValueOnDevice[extensions.debugPaint.extension],
        isFalse,
      );
      expect(
        fakeExtensionManager.extensionValueOnDevice[
            extensions.toggleOnDeviceWidgetInspector.extension],
        isTrue,
      );

      await tester.pumpWidget(buildInspectorScreen());

      expect(
        fakeExtensionManager.extensionValueOnDevice[
            extensions.toggleSelectWidgetMode.extension],
        isTrue,
      );

      // We need a frame to find out that the service extension state has changed.
      expect(find.byType(InspectorScreenBody), findsOneWidget);
      expect(
        find.text(extensions.toggleSelectWidgetMode.title),
        findsOneWidget,
      );
      expect(find.text(extensions.debugPaint.title), findsOneWidget);
      await tester.pump();
      await tester.tap(find.text(extensions.toggleSelectWidgetMode.title));
      expect(
        fakeExtensionManager.extensionValueOnDevice[
            extensions.toggleSelectWidgetMode.extension],
        isFalse,
      );
      // Verify the other service extension's state hasn't changed.
      expect(
        fakeExtensionManager
            .extensionValueOnDevice[extensions.debugPaint.extension],
        isFalse,
      );

      await tester.tap(find.text(extensions.toggleSelectWidgetMode.title));
      expect(
        fakeExtensionManager.extensionValueOnDevice[
            extensions.toggleSelectWidgetMode.extension],
        isTrue,
      );

      await tester.tap(find.text(extensions.debugPaint.title));
      expect(
        fakeExtensionManager
            .extensionValueOnDevice[extensions.debugPaint.extension],
        isTrue,
      );
    },
  );

  testWidgetsWithWindowSize(
    'Test toggling service extension buttons with no extensions available',
    windowSize,
    (WidgetTester tester) async {
      mockNoExtensionsAvailable();
      expect(
        fakeExtensionManager
            .extensionValueOnDevice[extensions.debugPaint.extension],
        isFalse,
      );
      expect(
        fakeExtensionManager.extensionValueOnDevice[
            extensions.toggleOnDeviceWidgetInspector.extension],
        isTrue,
      );

      await tester.pumpWidget(buildInspectorScreen());
      await tester.pump();
      expect(find.byType(InspectorScreenBody), findsOneWidget);
      expect(
        find.text(extensions.toggleOnDeviceWidgetInspector.title),
        findsOneWidget,
      );
      expect(find.text(extensions.debugPaint.title), findsOneWidget);
      await tester.pump();

      await tester
          .tap(find.text(extensions.toggleOnDeviceWidgetInspector.title));
      // Verify the service extension state has not changed.
      expect(
        fakeExtensionManager.extensionValueOnDevice[
            extensions.toggleOnDeviceWidgetInspector.extension],
        isTrue,
      );
      await tester
          .tap(find.text(extensions.toggleOnDeviceWidgetInspector.title));
      // Verify the service extension state has not changed.
      expect(
        fakeExtensionManager.extensionValueOnDevice[
            extensions.toggleOnDeviceWidgetInspector.extension],
        isTrue,
      );

      // TODO(jacobr): also verify that the service extension buttons look
      // visually disabled.
    },
  );

  group('LayoutDetailsTab', () {
    final renderObjectJson = jsonDecode(
      '''
        {
          "properties": [
            {
              "description": "horizontal",
              "name": "direction"
            },
            {
              "description": "start",
              "name": "mainAxisAlignment"
            },
            {
              "description": "max",
              "name": "mainAxisSize"
            },
            {
              "description": "center",
              "name": "crossAxisAlignment"
            },
            {
              "description": "ltr",
              "name": "textDirection"
            },
            {
              "description": "down",
              "name": "verticalDirection"
            }
          ]
        }
      ''',
    );
    final diagnostic = RemoteDiagnosticsNode(
      <String, Object?>{
        'widgetRuntimeType': 'Row',
        'renderObject': renderObjectJson,
        'hasChildren': false,
        'children': [],
      },
      null,
      false,
      null,
    );
    final treeNode = InspectorTreeNode()..diagnostic = diagnostic;
    testWidgetsWithWindowSize(
      'should render StoryOfYourFlexWidget',
      windowSize,
      (WidgetTester tester) async {
        final controller = TestInspectorV2Controller()
          ..setSelectedNode(treeNode);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LayoutExplorerTab(
                controller: controller,
              ),
            ),
          ),
        );
        expect(find.byType(FlexLayoutExplorerWidget), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'should listen to controller selection event',
      windowSize,
      (WidgetTester tester) async {
        final controller = TestInspectorV2Controller();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LayoutExplorerTab(
                controller: controller,
              ),
            ),
          ),
        );
        expect(find.byType(FlexLayoutExplorerWidget), findsNothing);
        controller.setSelectedNode(treeNode);
        await tester.pumpAndSettle();
        expect(find.byType(FlexLayoutExplorerWidget), findsOneWidget);
      },
    );
  });

  group(
    'FlutterInspectorSettingsDialog',
    () {
      const startingHoverEvalModeValue = false;

      setUp(() {
        preferences.inspector.setHoverEvalMode(startingHoverEvalModeValue);
      });

      testWidgetsWithWindowSize(
        'can update hover inspection setting',
        windowSize,
        (WidgetTester tester) async {
          await tester.pumpWidget(buildInspectorScreen());

          await tester.tap(find.byType(SettingsOutlinedButton));
          await tester.pumpAndSettle();
          expect(
            find.byType(FlutterInspectorSettingsDialog),
            findsOneWidget,
          );

          final hoverCheckBoxSetting = find.ancestor(
            of: find.richTextContaining('Enable hover inspection'),
            matching: find.byType(CheckboxSetting),
          );
          final hoverModeCheckBox = find.descendant(
            of: hoverCheckBoxSetting,
            matching: find.byType(NotifierCheckbox),
          );
          await tester.tap(hoverModeCheckBox);
          await tester.pumpAndSettle();
          expect(
            preferences.inspectorV2.hoverEvalModeEnabled.value,
            !startingHoverEvalModeValue,
          );
        },
      );
    },
  );

  // TODO(jacobr): add screenshot tests that connect to a test application
  // in the same way the inspector_controller test does today and take golden
  // images. Alternately: support an offline inspector mode and add tests of
  // that mode which would enable faster tests that run as unittests.
}
