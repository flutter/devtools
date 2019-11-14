// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/inspector/diagnostics_node.dart';
import 'package:devtools_app/src/inspector/flutter/inspector_data_models.dart';
import 'package:devtools_app/src/inspector/flutter/inspector_screen.dart';
import 'package:devtools_app/src/inspector/flutter/inspector_screen_details_tab.dart';
import 'package:devtools_app/src/inspector/flutter/story_of_your_layout/flex.dart';
import 'package:devtools_app/src/inspector/flutter/summary_tree_debug_layout.dart';
import 'package:devtools_app/src/inspector/inspector_controller.dart';
import 'package:devtools_app/src/inspector/inspector_tree.dart';
import 'package:devtools_app/src/service_extensions.dart' as extensions;
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../support/mocks.dart';
import 'wrappers.dart';

void main() {
  InspectorScreen screen;
  FakeServiceManager fakeServiceManager;
  FakeServiceExtensionManager fakeExtensionManager;
  group('Inspector Screen', () {
    setUp(() {
      fakeServiceManager = FakeServiceManager();
      fakeExtensionManager = fakeServiceManager.serviceExtensionManager;

      setGlobal(ServiceConnectionManager, fakeServiceManager);
      when(serviceManager.connectedApp.isAnyFlutterApp)
          .thenAnswer((_) => Future.value(true));

      screen = const InspectorScreen();
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
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('Flutter Inspector'), findsOneWidget);
    });

    testWidgets('builds with no data', (WidgetTester tester) async {
      // Make sure the window is wide enough to display description text.
      await setWindowSize(const Size(2600.0, 1200.0));
      await tester.pumpWidget(wrap(Builder(builder: screen.build)));
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

    testWidgets('Test toggling service extension buttons',
        (WidgetTester tester) async {
      await setWindowSize(const Size(2600.0, 1200.0));
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

      await tester.pumpWidget(wrap(Builder(builder: screen.build)));

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

    testWidgets(
        'Test toggling service extension buttons with no extensions available',
        (WidgetTester tester) async {
      await setWindowSize(const Size(2600.0, 1200.0));
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

      await tester.pumpWidget(wrap(Builder(builder: screen.build)));
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

    group('test render depends on enableExperimentalStoryOfLayout value', () {
      testWidgets('Should not render toggle button when flag is disabled',
          (WidgetTester tester) async {
        InspectorController.enableExperimentalStoryOfLayout = false;
        await setWindowSize(const Size(2600.0, 1200.0));
        await tester.pumpWidget(wrap(Builder(builder: screen.build)));
        expect(find.text('Show Constraints'), findsNothing);
      });

      testWidgets(
          'Should render button with full text when flag is enabled and screen is wide enough',
          (WidgetTester tester) async {
        InspectorController.enableExperimentalStoryOfLayout = true;
        await setWindowSize(const Size(2600.0, 1200.0));
        await tester.pumpWidget(wrap(Builder(builder: screen.build)));
        expect(find.text('Show Constraints'), findsWidgets);
      });

      // TODO(albertusangga): add unit test to test only show icon
    });

    testWidgets('Test render ConstraintsDescription',
        (WidgetTester tester) async {
      final jsonNode = <String, Object>{
        'constraints': <String, Object>{
          'type': 'BoxConstraints',
          'hasBoundedWidth': true,
          'hasBoundedHeight': false,
          'minWidth': 0.0,
          'maxWidth': 100.0,
          'minHeight': 0.0,
        },
      };
      final animationController = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 1),
      );
      final node = RemoteDiagnosticsNode(jsonNode, null, false, null);
      await tester.pumpWidget(
        MaterialApp(
          home: ConstraintsDescription(
            properties: LayoutProperties(node),
            listenable: animationController,
          ),
        ),
      );
      animationController.forward();
      await tester.pumpAndSettle();
      expect(find.byType(RichText), findsOneWidget);
      Finder findRichText(String textToMatch) {
        return find.byWidgetPredicate(
          (Widget widget) =>
              (widget is RichText) && widget.text.toPlainText() == textToMatch,
          description: 'Rich text contains $textToMatch',
        );
      }

      expect(findRichText('BoxConstraints(0.0<=w<=100.0,height unconstrained)'),
          findsOneWidget);
      animationController.dispose();
    });

    testWidgets('Test render LayoutDetailsTab', (WidgetTester tester) async {
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
          'isFlex': true,
          'renderObject': renderObjectJson,
          'hasChildren': false,
          'children': [],
        },
        null,
        false,
        null,
      );
      final treeNode = InspectorTreeNode()..diagnostic = diagnostic;
      final controller = MockInspectorController();
      when(controller.selectedNode).thenReturn(treeNode);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LayoutDetailsTab(
              controller: controller,
            ),
          ),
        ),
      );
      expect(find.byType(StoryOfYourFlexWidget), findsOneWidget);
    });

    // TODO(jacobr): add screenshot tests that connect to a test application
    // in the same way the inspector_controller test does today and take golden
    // images. Alternately: support an offline inspector mode and add tests of
    // that mode which would enable faster tests that run as unittests.
  });
}

class MockInspectorController extends Mock implements InspectorController {}
