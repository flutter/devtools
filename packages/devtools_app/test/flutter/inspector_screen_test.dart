// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/inspector/flutter/inspector_screen.dart';
import 'package:devtools_app/src/service_extensions.dart' as extensions;
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../support/mocks.dart';
import 'wrappers.dart';

void main() {
  InspectorScreen screen;
  MockServiceManager mockServiceManager;
  FakeServiceExtensionManager fakeExtensionManager;
  group('Inspector Screen', () {
    setUp(() {
      mockServiceManager = MockServiceManager();
      fakeExtensionManager = mockServiceManager.serviceExtensionManager;

      setGlobal(ServiceConnectionManager, mockServiceManager);
//      when(serviceManager.service.getFlagList()).thenAnswer((_) => null);
      when(serviceManager.connectedApp.isAnyFlutterApp)
          .thenAnswer((_) => Future.value(true));

      screen = const InspectorScreen();
    });

    void mockExtensions() {
      fakeExtensionManager.extensionValueOnDevice = {
        extensions.toggleSelectWidgetMode.extension: true,
        extensions.debugPaint.extension: false,
      };
      fakeExtensionManager
          .fakeAddServiceExtension(extensions.toggleSelectWidgetMode.extension);
      fakeExtensionManager
          .fakeAddServiceExtension(extensions.debugPaint.extension);
      fakeExtensionManager.fakeFrame();
    }

    void mockNoExtensionsAvailable() {
      fakeExtensionManager.extensionValueOnDevice = {
        extensions.toggleSelectWidgetMode.extension: true,
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
      await setWindowSize(const Size(1920.0, 1200.0));
      await tester.pumpWidget(wrap(Builder(builder: screen.build)));
      expect(find.byType(InspectorScreenBody), findsOneWidget);
      expect(find.text(extensions.toggleSelectWidgetMode.description),
          findsOneWidget);
      expect(find.text(extensions.debugPaint.description), findsOneWidget);
      // Make sure there is not an overflow if the window is shrunk.
      await setWindowSize(const Size(600.0, 1200.0));
      // Verify that description text is no-longer shown.
      expect(find.text(extensions.debugPaint.description), findsOneWidget);
    });

    testWidgets('Test toggling service extension buttons',
        (WidgetTester tester) async {
      await setWindowSize(const Size(1920.0, 1200.0));
      mockExtensions();
      expect(
        fakeExtensionManager
            .extensionValueOnDevice[extensions.debugPaint.extension],
        isFalse,
      );
      expect(
        fakeExtensionManager.extensionValueOnDevice[
            extensions.toggleSelectWidgetMode.extension],
        isTrue,
      );

      await tester.pumpWidget(wrap(Builder(builder: screen.build)));
      expect(find.byType(InspectorScreenBody), findsOneWidget);
      expect(find.text(extensions.toggleSelectWidgetMode.description),
          findsOneWidget);
      expect(find.text(extensions.debugPaint.description), findsOneWidget);
      await tester.pumpAndSettle();

      expect(
        fakeExtensionManager.extensionValueOnDevice[
            extensions.toggleSelectWidgetMode.extension],
        isTrue,
      );
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
      await setWindowSize(const Size(1920.0, 1200.0));
      mockNoExtensionsAvailable();
      expect(
        fakeExtensionManager
            .extensionValueOnDevice[extensions.debugPaint.extension],
        isFalse,
      );
      expect(
        fakeExtensionManager.extensionValueOnDevice[
            extensions.toggleSelectWidgetMode.extension],
        isTrue,
      );

      await tester.pumpWidget(wrap(Builder(builder: screen.build)));
      expect(find.byType(InspectorScreenBody), findsOneWidget);
      expect(find.text(extensions.toggleSelectWidgetMode.description),
          findsOneWidget);
      expect(find.text(extensions.debugPaint.description), findsOneWidget);
      await tester.pumpAndSettle();

      await tester
          .tap(find.text(extensions.toggleSelectWidgetMode.description));
      // Verify the service extension state has not changed.
      expect(
          fakeExtensionManager.extensionValueOnDevice[
              extensions.toggleSelectWidgetMode.extension],
          isTrue);
      await tester
          .tap(find.text(extensions.toggleSelectWidgetMode.description));
      // Verify the service extension state has not changed.
      expect(
          fakeExtensionManager.extensionValueOnDevice[
              extensions.toggleSelectWidgetMode.extension],
          isTrue);

      // TODO(jacobr): also verify that the service extension buttons look
      // visually disabled.
    });
  });
}
