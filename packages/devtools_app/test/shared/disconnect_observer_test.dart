// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/framework/disconnect_observer.dart';
import 'package:devtools_app/src/shared/framework_controller.dart';
import 'package:devtools_app_shared/shared.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DisconnectObserver', () {
    late FakeServiceConnectionManager fakeServiceConnectionManager;

    setUp(() {
      fakeServiceConnectionManager = FakeServiceConnectionManager();
      setGlobal(ServiceConnectionManager, fakeServiceConnectionManager);
      setGlobal(FrameworkController, FrameworkController());
      setGlobal(OfflineDataController, OfflineDataController());
      setGlobal(IdeTheme, IdeTheme());
    });

    Future<void> pumpDisconnectObserver(WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              return DisconnectObserver(
                routerDelegate: DevToolsRouterDelegate.of(context),
                child: const Placeholder(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    void verifyObserverState(
      WidgetTester tester, {
      required bool connected,
      required bool showingOverlay,
    }) {
      final DisconnectObserverState state =
          tester.state(find.byType(DisconnectObserver));
      expect(state.currentConnectionState.connected, connected);
      expect(
        state.currentDisconnectedOverlay,
        showingOverlay ? isNotNull : isNull,
      );
      expect(
        find.text('Disconnected'),
        showingOverlay ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(ConnectToNewAppButton),
        showingOverlay && !isEmbedded() ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Run a new debug session to reconnect'),
        showingOverlay && isEmbedded() ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Review recent data (offline)'),
        showingOverlay && offlineDataController.offlineDataJson.isNotEmpty
            ? findsOneWidget
            : findsNothing,
      );
    }

    testWidgets(
      'initiailized in a disconnected state',
      (WidgetTester tester) async {
        fakeServiceConnectionManager.serviceManager.setConnectedState(false);
        await pumpDisconnectObserver(tester);
        verifyObserverState(tester, connected: false, showingOverlay: false);
      },
    );

    testWidgets(
      'initiailized in a connected state',
      (WidgetTester tester) async {
        await pumpDisconnectObserver(tester);
        verifyObserverState(tester, connected: true, showingOverlay: false);
      },
    );

    testWidgets(
      'handles connection changes',
      (WidgetTester tester) async {
        fakeServiceConnectionManager.serviceManager.setConnectedState(false);
        await pumpDisconnectObserver(tester);
        verifyObserverState(tester, connected: false, showingOverlay: false);

        // Establish a connection.
        fakeServiceConnectionManager.serviceManager.setConnectedState(true);
        await tester.pumpAndSettle();
        verifyObserverState(tester, connected: true, showingOverlay: false);

        // Trigger a disconnect.
        fakeServiceConnectionManager.serviceManager.setConnectedState(false);
        await tester.pumpAndSettle();
        verifyObserverState(tester, connected: false, showingOverlay: true);

        // Trigger a reconnect.
        fakeServiceConnectionManager.serviceManager.setConnectedState(true);
        await tester.pumpAndSettle();
        verifyObserverState(tester, connected: true, showingOverlay: false);
      },
    );

    group('disconnected overlay', () {
      Future<void> showOverlayAndVerifyContents(WidgetTester tester) async {
        await pumpDisconnectObserver(tester);
        verifyObserverState(tester, connected: true, showingOverlay: false);
        fakeServiceConnectionManager.serviceManager.setConnectedState(false);
        await tester.pumpAndSettle();
        verifyObserverState(tester, connected: false, showingOverlay: true);
      }

      testWidgets(
        'builds for embedded mode',
        (WidgetTester tester) async {
          setGlobal(IdeTheme, IdeTheme(embedMode: EmbedMode.embedOne));
          await showOverlayAndVerifyContents(tester);
        },
      );

      testWidgets(
        'builds for reviewing history',
        (WidgetTester tester) async {
          offlineDataController.offlineDataJson = {'foo': 'bar'};
          await showOverlayAndVerifyContents(tester);
        },
      );
    });

    // TODO(kenz): test navigation that occurs by clicking on buttons. This will
    // require either modifying the test wrappers to take a set of routes or
    // writing an integration test for this user journey.
  });
}
