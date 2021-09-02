// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/inspector/diagnostics_node.dart';
import 'package:devtools_app/src/inspector/inspector_controller.dart';
import 'package:devtools_app/src/inspector/inspector_screen.dart';
import 'package:devtools_app/src/inspector/inspector_service.dart';
import 'package:devtools_app/src/inspector/inspector_tree.dart';
import 'package:devtools_app/src/inspector/layout_explorer/flex/flex.dart';
import 'package:devtools_app/src/inspector/layout_explorer/layout_explorer.dart';
import 'package:devtools_app/src/service_extensions.dart' as extensions;
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:mockito/mockito.dart';

import 'support/mocks.dart';
import 'support/wrappers.dart';

void main() {
  const screen = InspectorScreen();

  FakeServiceManager fakeServiceManager;
  FakeServiceExtensionManager fakeExtensionManager;
  const windowSize = Size(2600.0, 1200.0);

  final debuggerController = MockDebuggerController.withDefaults();

  Widget buildInspectorScreen() {
    return wrapWithControllers(
      Builder(builder: screen.build),
      debugger: debuggerController,
    );
  }

  group('Inspector Screen', () {
    setUp(() {
      fakeServiceManager = FakeServiceManager();
      fakeExtensionManager = fakeServiceManager.serviceExtensionManager;
      when(fakeServiceManager.connectedApp.isFlutterAppNow).thenReturn(true);
      when(fakeServiceManager.connectedApp.isProfileBuildNow).thenReturn(false);
      when(fakeServiceManager.errorBadgeManager.errorCountNotifier(any))
          .thenReturn(ValueNotifier<int>(0));

      setGlobal(ServiceConnectionManager, fakeServiceManager);
      mockIsFlutterApp(serviceManager.connectedApp);
    });

    void mockExtensions() {
      fakeExtensionManager.extensionValueOnDevice = {
        extensions.toggleSelectWidgetMode.extension: true,
        extensions.enableOnDeviceInspector.extension: true,
        extensions.toggleOnDeviceWidgetInspector.extension: true,
        extensions.debugPaint.extension: false,
      };
      fakeExtensionManager
        ..fakeAddServiceExtension(
            extensions.toggleOnDeviceWidgetInspector.extension)
        ..fakeAddServiceExtension(extensions.toggleSelectWidgetMode.extension)
        ..fakeAddServiceExtension(extensions.enableOnDeviceInspector.extension)
        ..fakeAddServiceExtension(extensions.debugPaint.extension)
        ..fakeFrame();
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

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(buildInspectorScreen());
      await tester.pumpAndSettle();
      expect(find.byType(InspectorScreenBody), findsOneWidget);
    });

    group('Widget Errors', () {
      // Display of error navigator/indicators is tested by a golden in
      // inspector_integration_test.dart

      testWidgetsWithWindowSize(
          'does not render error navigator if no errors', windowSize,
          (WidgetTester tester) async {
        await tester.pumpWidget(buildInspectorScreen());
        expect(find.byType(ErrorNavigator), findsNothing);
      });
    });

    testWidgetsWithWindowSize('builds with no data', windowSize,
        (WidgetTester tester) async {
      // Make sure the window is wide enough to display description text.

      await tester.pumpWidget(buildInspectorScreen());
      expect(find.byType(InspectorScreenBody), findsOneWidget);
      expect(find.text('Refresh Tree'), findsOneWidget);
      expect(find.text(extensions.debugPaint.description), findsOneWidget);
      // Make sure there is not an overflow if the window is narrow.
      // TODO(jacobr): determine why there are overflows in the test environment
      // but not on the actual device for this cae.
      // await setWindowSize(const Size(1000.0, 1200.0));
      // Verify that description text is no-longer shown.
      // expect(find.text(extensions.debugPaint.description), findsOneWidget);
    });

    testWidgetsWithWindowSize(
        'Test toggling service extension buttons', windowSize,
        (WidgetTester tester) async {
      mockExtensions();
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
        find.text(extensions.toggleSelectWidgetMode.description),
        findsOneWidget,
      );
      expect(find.text(extensions.debugPaint.description), findsOneWidget);
      await tester.pump();
      await tester
          .tap(find.text(extensions.toggleSelectWidgetMode.description));
      expect(
        fakeExtensionManager.extensionValueOnDevice[
            extensions.toggleSelectWidgetMode.extension],
        isFalse,
      );
      // Verify the the other service extension's state hasn't changed.
      expect(
        fakeExtensionManager
            .extensionValueOnDevice[extensions.debugPaint.extension],
        isFalse,
      );

      await tester
          .tap(find.text(extensions.toggleSelectWidgetMode.description));
      expect(
        fakeExtensionManager.extensionValueOnDevice[
            extensions.toggleSelectWidgetMode.extension],
        isTrue,
      );

      await tester.tap(find.text(extensions.debugPaint.description));
      expect(
        fakeExtensionManager
            .extensionValueOnDevice[extensions.debugPaint.extension],
        isTrue,
      );
    });

    testWidgetsWithWindowSize(
        'Test toggling service extension buttons with no extensions available',
        windowSize, (WidgetTester tester) async {
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
      expect(find.text(extensions.toggleOnDeviceWidgetInspector.description),
          findsOneWidget);
      expect(find.text(extensions.debugPaint.description), findsOneWidget);
      await tester.pump();

      await tester
          .tap(find.text(extensions.toggleOnDeviceWidgetInspector.description));
      // Verify the service extension state has not changed.
      expect(
          fakeExtensionManager.extensionValueOnDevice[
              extensions.toggleOnDeviceWidgetInspector.extension],
          isTrue);
      await tester
          .tap(find.text(extensions.toggleOnDeviceWidgetInspector.description));
      // Verify the service extension state has not changed.
      expect(
          fakeExtensionManager.extensionValueOnDevice[
              extensions.toggleOnDeviceWidgetInspector.extension],
          isTrue);

      // TODO(jacobr): also verify that the service extension buttons look
      // visually disabled.
    });

    group('LayoutDetailsTab', () {
      final renderObjectJson = jsonDecode('''
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
      ''');
      final diagnostic = RemoteDiagnosticsNode(
        <String, Object>{
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
          'should render StoryOfYourFlexWidget', windowSize,
          (WidgetTester tester) async {
        final controller = TestInspectorController()..setSelectedNode(treeNode);
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
      });

      testWidgetsWithWindowSize(
          'should listen to controller selection event', windowSize,
          (WidgetTester tester) async {
        final controller = TestInspectorController();
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
      });
    });

    // TODO(jacobr): add screenshot tests that connect to a test application
    // in the same way the inspector_controller test does today and take golden
    // images. Alternately: support an offline inspector mode and add tests of
    // that mode which would enable faster tests that run as unittests.
  });
}

class FakeInspectorService extends Fake implements InspectorService {
  @override
  ObjectGroup createObjectGroup(String debugName) {
    return ObjectGroup(debugName, this);
  }

  @override
  Future<bool> isWidgetTreeReady() async {
    return false;
  }

  @override
  Future<List<String>> inferPubRootDirectoryIfNeeded() async {
    return ['/some/directory'];
  }

  @override
  bool get useDaemonApi => true;

  @override
  final Set<InspectorServiceClient> clients = {};

  @override
  void addClient(InspectorServiceClient client) {
    clients.add(client);
  }

  @override
  void removeClient(InspectorServiceClient client) {
    clients.remove(client);
  }
}

class MockInspectorTreeController extends Mock
    implements InspectorTreeController {}

class TestInspectorController extends Fake implements InspectorController {
  InspectorService service = FakeInspectorService();

  @override
  ValueListenable<InspectorTreeNode> get selectedNode => _selectedNode;
  final ValueNotifier<InspectorTreeNode> _selectedNode = ValueNotifier(null);

  @override
  void setSelectedNode(InspectorTreeNode newSelection) {
    _selectedNode.value = newSelection;
  }

  @override
  InspectorService get inspectorService => service;
}
