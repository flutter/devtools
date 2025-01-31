// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/framework/initializer.dart';
import 'package:devtools_app/src/shared/framework/framework_controller.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('Initializer', () {
    const initializedKey = Key('initialized');
    const waitingText = 'Waiting for VM service connection...';
    const cannotConnectText = 'Cannot connect to VM service.';

    late FakeServiceConnectionManager fakeServiceConnectionManager;

    setUp(() {
      fakeServiceConnectionManager = FakeServiceConnectionManager();
      when(
        fakeServiceConnectionManager.serviceManager.connectedApp!.isDartWebApp,
      ).thenAnswer((_) => Future.value(false));
      setGlobal(ServiceConnectionManager, fakeServiceConnectionManager);
      setGlobal(FrameworkController, FrameworkController());
      setGlobal(OfflineDataController, OfflineDataController());
      setGlobal(IdeTheme, IdeTheme());
    });

    Future<void> pumpInitializer(WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(Initializer(builder: (_) => const SizedBox(key: initializedKey))),
      );
      await tester.pump();
    }

    Future<void> advanceTimer(WidgetTester tester) async {
      // Wait a short delay to let the initializer timer advance.
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    testWidgets('immediately calls builder when connection exists', (
      WidgetTester tester,
    ) async {
      await pumpInitializer(tester);
      expect(find.text(waitingText), findsNothing);
      expect(find.text(cannotConnectText), findsNothing);
      expect(find.byType(ConnectToNewAppButton), findsNothing);
      expect(find.byKey(initializedKey), findsOneWidget);

      // Verify expectations are still true after the timer advances.
      await advanceTimer(tester);
      expect(find.text(waitingText), findsNothing);
      expect(find.text(cannotConnectText), findsNothing);
      expect(find.byType(ConnectToNewAppButton), findsNothing);
      expect(find.byKey(initializedKey), findsOneWidget);
    });

    testWidgets('calls builder late if connection is established late', (
      WidgetTester tester,
    ) async {
      fakeServiceConnectionManager.serviceManager.setConnectedState(false);

      await pumpInitializer(tester);
      expect(find.text(waitingText), findsOneWidget);
      expect(find.text(cannotConnectText), findsNothing);
      expect(find.byType(ConnectToNewAppButton), findsNothing);
      expect(find.byKey(initializedKey), findsNothing);

      fakeServiceConnectionManager.serviceManager.setConnectedState(true);
      await tester.pump();

      expect(find.text(waitingText), findsNothing);
      expect(find.text(cannotConnectText), findsNothing);
      expect(find.byType(ConnectToNewAppButton), findsNothing);
      expect(find.byKey(initializedKey), findsOneWidget);

      // Verify expectations are still true after the timer advances.
      await advanceTimer(tester);
      expect(find.text(waitingText), findsNothing);
      expect(find.text(cannotConnectText), findsNothing);
      expect(find.byType(ConnectToNewAppButton), findsNothing);
      expect(find.byKey(initializedKey), findsOneWidget);
    });

    testWidgets(
      'shows cannot connect message if connection is not established',
      (WidgetTester tester) async {
        fakeServiceConnectionManager.serviceManager.setConnectedState(false);

        await pumpInitializer(tester);
        expect(find.text(waitingText), findsOneWidget);
        expect(find.text(cannotConnectText), findsNothing);
        expect(find.byType(ConnectToNewAppButton), findsNothing);
        expect(find.byKey(initializedKey), findsNothing);

        await advanceTimer(tester);
        expect(find.text(waitingText), findsNothing);
        expect(find.text(cannotConnectText), findsOneWidget);
        expect(find.byType(ConnectToNewAppButton), findsOneWidget);
        expect(find.byKey(initializedKey), findsNothing);
      },
    );
  });
}
