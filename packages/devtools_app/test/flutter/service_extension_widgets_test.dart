// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_extensions.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/service_registrations.dart';
import 'package:devtools_app/src/ui/flutter/service_extension_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../support/mocks.dart';
import 'wrappers.dart';

void main() {
  MockServiceManager mockServiceManager;
  setUp(() {
    mockServiceManager = MockServiceManager();
    when(mockServiceManager.serviceExtensionManager)
        .thenReturn(FakeServiceExtensionManager());
    setGlobal(
      ServiceConnectionManager,
      mockServiceManager,
    );
  });
  group('Hot Reload Button', () {
    int reloads = 0;

    setUp(() {
      reloads = 0;
      when(mockServiceManager.performHotReload()).thenAnswer((invocation) {
        reloads++;
        return Future<void>.value();
      });
    });

    testWidgets('performs a hot reload when pressed',
        (WidgetTester tester) async {
      registerServiceExtension(mockServiceManager, hotReload);
      final button = HotReloadButton();
      await tester.pumpWidget(wrap(Scaffold(body: Center(child: button))));
      expect(find.byWidget(button), findsOneWidget);
      await tester.pumpAndSettle();
      expect(reloads, 0);
      await tester.tap(find.byWidget(button));
      await tester.pumpAndSettle();
      expect(reloads, 1);
    });

    testWidgets(
        'does not perform a hot reload when the extension is not registered.',
        (WidgetTester tester) async {
      registerServiceExtension(
        mockServiceManager,
        hotReload,
        serviceAvailable: false,
      );
      final button = HotReloadButton();
      await tester.pumpWidget(wrap(Scaffold(body: Center(child: button))));
      expect(find.byWidget(button), findsOneWidget);
      await tester.pumpAndSettle();
      expect(reloads, 0);
      await tester.tap(find.byWidget(button));
      await tester.pumpAndSettle();
      expect(reloads, 0);
    });
  });

  group('Hot Restart Button', () {
    int restarts = 0;

    setUp(() {
      restarts = 0;
      when(mockServiceManager.performHotRestart()).thenAnswer((invocation) {
        restarts++;
        return Future<void>.value();
      });
    });

    testWidgets('performs a hot restart when pressed',
        (WidgetTester tester) async {
      registerServiceExtension(mockServiceManager, hotRestart);
      final button = HotRestartButton();
      await tester.pumpWidget(wrap(Scaffold(body: Center(child: button))));
      expect(find.byWidget(button), findsOneWidget);
      await tester.pumpAndSettle();
      expect(restarts, 0);
      await tester.tap(find.byWidget(button));
      await tester.pumpAndSettle();
      expect(restarts, 1);
    });

    testWidgets(
        'does not perform a hot restart when the service is not available',
        (WidgetTester tester) async {
      registerServiceExtension(
        mockServiceManager,
        hotRestart,
        serviceAvailable: false,
      );
      final button = HotRestartButton();
      await tester.pumpWidget(wrap(Scaffold(body: Center(child: button))));
      expect(find.byWidget(button), findsOneWidget);
      await tester.pumpAndSettle();
      expect(restarts, 0);
      await tester.tap(find.byWidget(button));
      await tester.pumpAndSettle();
      expect(restarts, 0);
    });
  });

  group('Structured Errors toggle', () {
    StreamSubscription serviceState;
    ServiceExtensionState mostRecentState;
    setUp(() {
      (mockServiceManager.serviceExtensionManager
              as FakeServiceExtensionManager)
          .fakeFrame();
      serviceState =
          mockServiceManager.serviceExtensionManager.getServiceExtensionState(
        structuredErrors.extension,
        (data) {
          mostRecentState = data;
        },
      );
    });

    tearDown(() async {
      await serviceState.cancel();
    });
    testWidgets('toggles', (WidgetTester tester) async {
      await (mockServiceManager.serviceExtensionManager
              as FakeServiceExtensionManager)
          .fakeAddServiceExtension(structuredErrors.extension);

      final button = StructuredErrorsToggle();
      await tester.pumpWidget(wrap(Scaffold(body: Center(child: button))));
      expect(find.byWidget(button), findsOneWidget);
      await tester.tap(find.byWidget(button));
      await tester.pumpAndSettle();
      (mockServiceManager.serviceExtensionManager
              as FakeServiceExtensionManager)
          .fakeFrame();
      expect(mostRecentState.value, true);
      await tester.tap(find.byWidget(button));
      await tester.pumpAndSettle();
      expect(mostRecentState.value, false);
    });

    testWidgets('updates based on the service extension',
        (WidgetTester tester) async {
      await (mockServiceManager.serviceExtensionManager
              as FakeServiceExtensionManager)
          .fakeAddServiceExtension(structuredErrors.extension);
      final button = StructuredErrorsToggle();
      await tester.pumpWidget(wrap(Scaffold(body: Center(child: button))));
      expect(find.byWidget(button), findsOneWidget);

      await mockServiceManager.serviceExtensionManager
          .setServiceExtensionState(structuredErrors.extension, true, true);
      await tester.pumpAndSettle();
      expect(toggle.value, true, reason: 'The extension is enabled.');

      await mockServiceManager.serviceExtensionManager
          .setServiceExtensionState(structuredErrors.extension, false, false);
      await tester.pumpAndSettle();
      expect(toggle.value, false, reason: 'The extension is disabled.');
    });
  });
}

void registerServiceExtension(
  MockServiceManager mockServiceManager,
  RegisteredServiceDescription description, {
  bool serviceAvailable = true,
}) {
  when(mockServiceManager.hasRegisteredService(description.service, any))
      .thenAnswer((invocation) {
    final onData = invocation.positionalArguments[1];
    return Stream<bool>.value(serviceAvailable).listen(onData);
  });
}

Switch get toggle => find.byType(Switch).evaluate().first.widget;
