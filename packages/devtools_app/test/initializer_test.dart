// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:devtools_app/src/service/service_manager.dart';
@TestOn('vm')
import 'package:devtools_app/src/shared/framework_controller.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/initializer.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('Initializer', () {
    late MaterialApp app;
    const Key initializedKey = Key('initialized');
    setUp(() async {
      await ensureInspectorDependencies();
      final serviceManager = FakeServiceManager();
      when(serviceManager.connectedApp!.isDartWebApp)
          .thenAnswer((_) => Future.value(false));
      setGlobal(ServiceConnectionManager, serviceManager);
      setGlobal(FrameworkController, FrameworkController());

      app = MaterialApp(
        initialRoute: '/init',
        routes: {
          '/init': (_) => Initializer(
                // ignore: avoid_redundant_argument_values
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
