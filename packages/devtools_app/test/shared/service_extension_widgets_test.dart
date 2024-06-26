// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/service/service_extension_widgets.dart';
import 'package:devtools_app/src/service/service_extensions.dart' as extensions;
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/service/service_registrations.dart';
import 'package:devtools_app/src/shared/connected_app.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_app/src/shared/primitives/message_bus.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late MockServiceConnectionManager mockServiceConnection;
  late MockServiceManager mockServiceManager;

  setUp(() {
    mockServiceConnection = createMockServiceConnectionWithDefaults();
    mockServiceManager =
        mockServiceConnection.serviceManager as MockServiceManager;
    when(mockServiceConnection.appState).thenReturn(
      AppState(
        mockServiceManager.isolateManager.selectedIsolate,
      ),
    );
    when(unawaited(mockServiceManager.runDeviceBusyTask(any)))
        .thenAnswer((_) => Future<void>.value());
    when(mockServiceManager.isMainIsolatePaused).thenReturn(false);
    setGlobal(ServiceConnectionManager, mockServiceConnection);
    setGlobal(NotificationService, NotificationService());
    setGlobal(IdeTheme, IdeTheme());
  });

  group('Hot Reload Button', () {
    int reloads = 0;

    setUp(() {
      reloads = 0;

      // Intentionally unawaited.
      // ignore: discarded_futures
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
        const button = HotReloadButton();
        await tester.pumpWidget(
          wrap(
            wrapWithNotifications(
              const Scaffold(body: Center(child: button)),
            ),
          ),
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
        const button = HotReloadButton();
        await tester
            .pumpWidget(wrap(const Scaffold(body: Center(child: button))));
        expect(find.byWidget(button), findsOneWidget);
        await tester.pumpAndSettle();
        expect(reloads, 0);
        await tester.tap(find.byWidget(button), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(reloads, 0);
      },
    );
  });

  group('Hot Restart Button', () {
    int restarts = 0;

    setUp(() {
      restarts = 0;

      // Intentionally unawaited.
      // ignore: discarded_futures
      when(mockServiceManager.performHotRestart()).thenAnswer((invocation) {
        restarts++;
        return Future<void>.value();
      });
    });

    testWidgetsWithContext(
      'performs a hot restart when pressed',
      (WidgetTester tester) async {
        registerServiceExtension(mockServiceManager, hotRestart);
        const button = HotRestartButton();
        await tester.pumpWidget(
          wrap(
            wrapWithNotifications(
              const Scaffold(body: Center(child: button)),
            ),
          ),
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
        const button = HotRestartButton();
        await tester
            .pumpWidget(wrap(const Scaffold(body: Center(child: button))));
        expect(find.byWidget(button), findsOneWidget);
        await tester.pumpAndSettle();
        expect(restarts, 0);
        await tester.tap(find.byWidget(button), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(restarts, 0);
      },
    );
  });

  group('Structured Errors toggle', () {
    late ValueListenable<ServiceExtensionState> serviceState;
    late ServiceExtensionState mostRecentState;
    void serviceStateListener() {
      mostRecentState = serviceState.value;
    }

    setUp(() async {
      await (mockServiceManager.serviceExtensionManager
              as FakeServiceExtensionManager)
          .fakeFrame();
      serviceState = mockServiceConnection
          .serviceManager.serviceExtensionManager
          .getServiceExtensionState(extensions.structuredErrors.extension);
      serviceState.addListener(serviceStateListener);
    });

    tearDown(() {
      serviceState.removeListener(serviceStateListener);
    });

    testWidgets('toggles', (WidgetTester tester) async {
      await (mockServiceManager.serviceExtensionManager
              as FakeServiceExtensionManager)
          .fakeAddServiceExtension(extensions.structuredErrors.extension);

      const button = StructuredErrorsToggle();
      await tester
          .pumpWidget(wrap(const Scaffold(body: Center(child: button))));
      expect(find.byWidget(button), findsOneWidget);
      await tester.tap(find.byWidget(button));
      await tester.pumpAndSettle();
      await (mockServiceManager.serviceExtensionManager
              as FakeServiceExtensionManager)
          .fakeFrame();
      expect(mostRecentState.value, true);
      await tester.tap(find.byWidget(button));
      await tester.pumpAndSettle();
      expect(mostRecentState.value, false);
    });

    testWidgets(
      'updates based on the service extension',
      (WidgetTester tester) async {
        await (mockServiceManager.serviceExtensionManager
                as FakeServiceExtensionManager)
            .fakeAddServiceExtension(extensions.structuredErrors.extension);
        const button = StructuredErrorsToggle();
        await tester
            .pumpWidget(wrap(const Scaffold(body: Center(child: button))));
        expect(find.byWidget(button), findsOneWidget);

        await mockServiceManager.serviceExtensionManager
            .setServiceExtensionState(
          extensions.structuredErrors.extension,
          enabled: true,
          value: true,
        );
        await tester.pumpAndSettle();
        expect(toggle.value, true, reason: 'The extension is enabled.');

        await mockServiceManager.serviceExtensionManager
            .setServiceExtensionState(
          extensions.structuredErrors.extension,
          enabled: false,
          value: false,
        );
        await tester.pumpAndSettle();
        expect(toggle.value, false, reason: 'The extension is disabled.');
      },
    );
  });
}

void registerServiceExtension(
  MockServiceManager mockServiceManager,
  RegisteredServiceDescription description, {
  bool serviceAvailable = true,
}) {
  when(
    mockServiceManager.registeredServiceListenable(description.service),
  ).thenAnswer((invocation) {
    final listenable = ImmediateValueNotifier(serviceAvailable);
    return listenable;
  });
}

Switch get toggle => find.byType(Switch).evaluate().first.widget as Switch;
