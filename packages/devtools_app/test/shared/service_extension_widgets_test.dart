// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/framework/notifications.dart';
import 'package:devtools_app/src/primitives/message_bus.dart';
import 'package:devtools_app/src/primitives/notifications.dart';
import 'package:devtools_app/src/primitives/utils.dart';
import 'package:devtools_app/src/service/service_extension_manager.dart';
import 'package:devtools_app/src/service/service_extension_widgets.dart';
import 'package:devtools_app/src/service/service_extensions.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/service/service_registrations.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  final mockServiceManager = MockServiceConnectionManager();
  when(mockServiceManager.serviceExtensionManager)
      .thenReturn(FakeServiceExtensionManager());
  setGlobal(ServiceConnectionManager, mockServiceManager);
  setGlobal(NotificationService, NotificationController());

  group('Hot Reload Button', () {
    int reloads = 0;

    setUp(() {
      reloads = 0;
      when(mockServiceManager.performHotReload()).thenAnswer((invocation) {
        reloads++;
        return Future<void>.value();
      });
      setGlobal(IdeTheme, IdeTheme());
    });

    testWidgetsWithContext(
      'performs a hot reload when pressed',
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
      },
      context: {
        MessageBus: MessageBus(),
      },
    );

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
      await tester.tap(find.byWidget(button), warnIfMissed: false);
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

    testWidgetsWithContext(
      'performs a hot restart when pressed',
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
      },
      context: {
        MessageBus: MessageBus(),
      },
    );

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
      await tester.tap(find.byWidget(button), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(restarts, 0);
    });
  });

  group('Structured Errors toggle', () {
    late ValueListenable<ServiceExtensionState> serviceState;
    late ServiceExtensionState mostRecentState;
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

      await mockServiceManager.serviceExtensionManager.setServiceExtensionState(
        structuredErrors.extension,
        enabled: true,
        value: true,
      );
      await tester.pumpAndSettle();
      expect(toggle.value, true, reason: 'The extension is enabled.');

      await mockServiceManager.serviceExtensionManager.setServiceExtensionState(
        structuredErrors.extension,
        enabled: false,
        value: false,
      );
      await tester.pumpAndSettle();
      expect(toggle.value, false, reason: 'The extension is disabled.');
    });
  });
}

void registerServiceExtension(
  MockServiceConnectionManager mockServiceManager,
  RegisteredServiceDescription description, {
  bool serviceAvailable = true,
}) {
  when(mockServiceManager.registeredServiceListenable(description.service))
      .thenAnswer((invocation) {
    final listenable = ImmediateValueNotifier(serviceAvailable);
    return listenable;
  });
}

Switch get toggle => find.byType(Switch).evaluate().first.widget as Switch;
