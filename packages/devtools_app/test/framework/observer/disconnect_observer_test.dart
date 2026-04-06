// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/framework/observer/disconnect_observer.dart';
import 'package:devtools_app/src/shared/framework/framework_controller.dart';
import 'package:devtools_app/src/shared/primitives/query_parameters.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/shared.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../test_infra/matchers/matchers.dart';

void main() {
  group('DisconnectObserver', () {
    late FakeServiceConnectionManager fakeServiceConnectionManager;
    late MockDTDManager mockDtdManager;

    setUp(() {
      fakeServiceConnectionManager = FakeServiceConnectionManager();
      mockDtdManager = MockDTDManager();
      when(mockDtdManager.reconnect()).thenAnswer((_) async {});
      setGlobal(ServiceConnectionManager, fakeServiceConnectionManager);
      setGlobal(DTDManager, mockDtdManager);
      setGlobal(FrameworkController, FrameworkController());
      setGlobal(OfflineDataController, OfflineDataController());
      setGlobal(IdeTheme, IdeTheme());
    });

    Future<void> pumpDisconnectObserver(
      WidgetTester tester, {
      Widget child = const Placeholder(),
      DevToolsQueryParams? queryParams,
    }) async {
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              return DisconnectObserver(
                routerDelegate: DevToolsRouterDelegate.of(context),
                child: child,
              );
            },
          ),
          queryParams: queryParams,
        ),
      );
      await tester.pumpAndSettle();
    }

    void verifyObserverState(
      WidgetTester tester, {
      required bool connected,
      required bool showingOverlay,
    }) {
      final DisconnectObserverState state = tester.state(
        find.byType(DisconnectObserver),
      );
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
      // The Reconnect button should be present in both embedded and
      // non-embedded modes when the overlay is showing.
      expect(
        find.text('Reconnect'),
        showingOverlay ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Or run a new debug session to connect to it.'),
        showingOverlay && isEmbedded() ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Review recent data (offline)'),
        showingOverlay && offlineDataController.offlineDataJson.isNotEmpty
            ? findsOneWidget
            : findsNothing,
      );
    }

    testWidgets('initialized in a disconnected state', (
      WidgetTester tester,
    ) async {
      fakeServiceConnectionManager.serviceManager.setConnectedState(false);
      await pumpDisconnectObserver(tester);
      verifyObserverState(tester, connected: false, showingOverlay: false);
    });

    testWidgets('initialized in a connected state', (
      WidgetTester tester,
    ) async {
      await pumpDisconnectObserver(tester);
      verifyObserverState(tester, connected: true, showingOverlay: false);
    });

    testWidgets('handles connection changes', (WidgetTester tester) async {
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
    });

    group('disconnected overlay', () {
      Future<void> showOverlayAndVerifyContents(WidgetTester tester) async {
        await pumpDisconnectObserver(tester);
        verifyObserverState(tester, connected: true, showingOverlay: false);
        fakeServiceConnectionManager.serviceManager.setConnectedState(false);
        await tester.pumpAndSettle();
        verifyObserverState(tester, connected: false, showingOverlay: true);
      }

      testWidgets('builds for embedded mode', (WidgetTester tester) async {
        setGlobal(IdeTheme, IdeTheme(embedMode: EmbedMode.embedOne));
        await showOverlayAndVerifyContents(tester);
      });

      testWidgets('builds for reviewing history', (WidgetTester tester) async {
        offlineDataController.offlineDataJson = {'foo': 'bar'};
        await showOverlayAndVerifyContents(tester);
      });

      testWidgets(
        'reconnect button restores previous VM service URI on success',
        (WidgetTester tester) async {
          const previousVmServiceUri = 'http://127.0.0.1:8181/';
          when(mockDtdManager.reconnect()).thenAnswer((_) async {
            fakeServiceConnectionManager.serviceManager.setConnectedState(true);
          });

          await pumpDisconnectObserver(
            tester,
            queryParams: DevToolsQueryParams({
              DevToolsQueryParams.vmServiceUriKey: previousVmServiceUri,
            }),
          );
          verifyObserverState(tester, connected: true, showingOverlay: false);

          fakeServiceConnectionManager.serviceManager.setConnectedState(false);
          await tester.pumpAndSettle();
          verifyObserverState(tester, connected: false, showingOverlay: true);

          await tester.tap(find.text('Reconnect'));
          await tester.pumpAndSettle();

          verify(mockDtdManager.reconnect()).called(1);
          verifyObserverState(tester, connected: true, showingOverlay: false);
          final context = tester.element(find.byType(DisconnectObserver));
          final routerDelegate = DevToolsRouterDelegate.of(context);
          expect(
            routerDelegate.currentConfiguration!.params.vmServiceUri,
            previousVmServiceUri,
          );
        },
      );

      // Regression test for https://github.com/flutter/devtools/issues/8050.
      testWidgets('hides widgets at lower z-index', (
        WidgetTester tester,
      ) async {
        await pumpDisconnectObserver(
          tester,
          child: Container(height: 100.0, width: 100.0, color: Colors.red),
        );
        verifyObserverState(tester, connected: true, showingOverlay: false);
        // At this point the red container should be visible.
        await expectLater(
          find.byType(MaterialApp),
          matchesDevToolsGolden(
            '../../test_infra/goldens/shared/disconnect_observer_connected.png',
          ),
        );

        // Trigger a disconnect.
        fakeServiceConnectionManager.serviceManager.setConnectedState(false);
        await tester.pumpAndSettle();

        verifyObserverState(tester, connected: false, showingOverlay: true);
        // Once the disconnect overlay is showing, the red container should
        // be hidden.
        await expectLater(
          find.byType(MaterialApp),
          matchesDevToolsGolden(
            '../../test_infra/goldens/shared/disconnect_observer_disconnected.png',
          ),
        );
      });
    });

    // TODO(kenz): test navigation that occurs by clicking on buttons. This will
    // require either modifying the test wrappers to take a set of routes or
    // writing an integration test for this user journey.
  });
}
