// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/initializer.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'support/mocks.dart';

void main() {
  group('Initializer', () {
    MaterialApp app;
    const Key initializedKey = Key('initialized');
    setUp(() async {
      await ensureInspectorDependencies();
      final serviceManager = FakeServiceManager();
      when(serviceManager.connectedApp.isDartWebApp)
          .thenAnswer((_) => Future.value(false));
      setGlobal(
        ServiceConnectionManager,
        serviceManager,
      );

      app = MaterialApp(
        initialRoute: '/init',
        routes: {
          '/init': (_) => Initializer(
                url: null,
                builder: (_) => const SizedBox(key: initializedKey),
              ),
        },
      );
    });

    testWidgets('shows disconnected overlay if not connected',
        (WidgetTester tester) async {
      setGlobal(
        ServiceConnectionManager,
        FakeServiceManager(
          hasConnection: false,
        ),
      );

      await tester.pumpFrames(app, const Duration(milliseconds: 100));
      expect(find.text('Disconnected'), findsOneWidget);
    });

    testWidgets('shows disconnected overlay upon disconnect',
        (WidgetTester tester) async {
      final serviceManager = FakeServiceManager();
      setGlobal(ServiceConnectionManager, serviceManager);

      // Expect standard connected state.
      await tester.pumpFrames(app, const Duration(milliseconds: 100));
      expect(find.byKey(initializedKey), findsOneWidget);
      expect(find.text('Disconnected'), findsNothing);

      // Trigger a disconnect.
      serviceManager.changeState(false);

      // Expect Disconnected overlay.
      await tester.pumpFrames(app, const Duration(milliseconds: 100));
      expect(find.text('Disconnected'), findsOneWidget);
    });

    testWidgets('closes disconnected overlay upon reconnect',
        (WidgetTester tester) async {
      final serviceManager = FakeServiceManager();
      setGlobal(ServiceConnectionManager, serviceManager);

      // Trigger a disconnect and ensure the overlay appears.
      await tester.pumpFrames(app, const Duration(milliseconds: 100));
      serviceManager.changeState(false);
      await tester.pumpFrames(app, const Duration(milliseconds: 100));
      expect(find.text('Disconnected'), findsOneWidget);

      // Trigger a reconnect
      serviceManager.changeState(true);

      // Expect no overlay.
      await tester.pumpFrames(app, const Duration(milliseconds: 100));
      expect(find.text('Disconnected'), findsNothing);
    });

    testWidgets('builds contents when initialized',
        (WidgetTester tester) async {
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Disconnected'), findsNothing);
      expect(find.byKey(initializedKey), findsOneWidget);
    });
  });
}
