// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/core/message_bus.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/notifications.dart';
import 'package:devtools_app/src/service_extensions.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/service_registrations.dart';
import 'package:devtools_app/src/ui/service_extension_widgets.dart';
import 'package:devtools_app/src/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'support/mocks.dart';
import 'support/wrappers.dart';

void main() {
  MockServiceManager mockServiceManager;

  setUp(() {
    mockServiceManager = MockServiceManager();
    when(mockServiceManager.serviceExtensionManager)
        .thenReturn(FakeServiceExtensionManager());
    setGlobal(ServiceConnectionManager, mockServiceManager);
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

    testWidgetsWithContext('performs a hot reload when pressed',
        (WidgetTester tester) async {
      registerServiceExtension(mockServiceManager, hotReload);
      final button = HotReloadButton();
      await tester.pumpWidget(
        wrap(wrapWithNotifications(Scaffold(body: Center(child: button)))),
      );
      expect(find.byWidget(button), findsOneWidget);
      await tester.pumpAndSettle();
      expect(reloads, 0);
      await tester.tap(find.byWidget(button));
      await tester.pumpAndSettle();
      expect(reloads, 1);
    }, context: {
      MessageBus: MessageBus(),
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

    testWidgetsWithContext('performs a hot restart when pressed',
        (WidgetTester tester) async {
      registerServiceExtension(mockServiceManager, hotRestart);
      final button = HotRestartButton();
      await tester.pumpWidget(
        wrap(wrapWithNotifications(Scaffold(body: Center(child: button)))),
      );
      expect(find.byWidget(button), findsOneWidget);
      await tester.pumpAndSettle();
      expect(restarts, 0);
      await tester.tap(find.byWidget(button));
      await tester.pumpAndSettle();
      expect(restarts, 1);
    }, context: {
      MessageBus: MessageBus(),
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
    ValueListenable<ServiceExtensionState> serviceState;
    ServiceExtensionState mostRecentState;
    final serviceStateListener = () {
      mostRecentState = serviceState.value;
    };

    setUp(() {
      (mockServiceManager.serviceExtensionManager
              as FakeServiceExtensionManager)
          .fakeFrame();
      serviceState = mockServiceManager.serviceExtensionManager
          .getServiceExtensionState(structuredErrors.extension);
      serviceState.addListener(serviceStateListener);
    });

    tearDown(() async {
      serviceState.removeListener(serviceStateListener);
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

Widget wrapWithNotifications(Widget child) {
  return Notifications(child: child);
}

void registerServiceExtension(
  MockServiceManager mockServiceManager,
  RegisteredServiceDescription description, {
  bool serviceAvailable = true,
}) {
  when(mockServiceManager.registeredServiceListenable(description.service))
      .thenAnswer((invocation) {
    final listenable = ImmediateValueNotifier(serviceAvailable);
    return listenable;
  });
}

Switch get toggle => find.byType(Switch).evaluate().first.widget;
