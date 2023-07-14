// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/framework/initializer.dart';
import 'package:devtools_app/src/shared/framework_controller.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('Initializer', () {
    const Key initializedKey = Key('initialized');
    setUp(() {
      final serviceManager = FakeServiceManager();
      when(serviceManager.connectedApp!.isDartWebApp)
          .thenAnswer((_) => Future.value(false));
      setGlobal(ServiceConnectionManager, serviceManager);
      setGlobal(FrameworkController, FrameworkController());
      setGlobal(OfflineModeController, OfflineModeController());
      setGlobal(IdeTheme, IdeTheme());
    });

    Future<void> pumpInitializer(WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          Initializer(
            url: null,
            builder: (_) => const SizedBox(key: initializedKey),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'shows disconnected overlay if not connected',
      (WidgetTester tester) async {
        setGlobal(
          ServiceConnectionManager,
          FakeServiceManager(
            hasConnection: false,
          ),
        );
        await pumpInitializer(tester);
        expect(find.text('Disconnected'), findsOneWidget);
      },
    );

    testWidgets(
      'shows disconnected overlay upon disconnect',
      (WidgetTester tester) async {
        final serviceManager = FakeServiceManager();
        setGlobal(ServiceConnectionManager, serviceManager);

        // Expect standard connected state.
        serviceManager.changeState(true);
        await pumpInitializer(tester);
        expect(find.byKey(initializedKey), findsOneWidget);
        expect(find.text('Disconnected'), findsNothing);

        // Trigger a disconnect.
        serviceManager.changeState(false);
        await tester.pumpAndSettle(const Duration(microseconds: 1000));

        // Expect Disconnected overlay.
        expect(find.text('Disconnected'), findsOneWidget);
      },
    );

    testWidgets(
      'closes disconnected overlay upon reconnect',
      (WidgetTester tester) async {
        final serviceManager = FakeServiceManager();
        setGlobal(ServiceConnectionManager, serviceManager);

        // Expect standard connected state.
        serviceManager.changeState(true);
        await pumpInitializer(tester);
        expect(find.byKey(initializedKey), findsOneWidget);
        expect(find.text('Disconnected'), findsNothing);

        // Trigger a disconnect and ensure the overlay appears.
        serviceManager.changeState(false);
        await tester.pumpAndSettle();
        expect(find.text('Disconnected'), findsOneWidget);

        // Trigger a reconnect
        serviceManager.changeState(true);
        await tester.pumpAndSettle();

        // Expect no overlay.
        expect(find.text('Disconnected'), findsNothing);
      },
    );
  });
}
