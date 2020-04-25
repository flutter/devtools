// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/flutter/split.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/network/flutter/http_request_inspector.dart';
import 'package:devtools_app/src/network/flutter/http_request_inspector_views.dart';
import 'package:devtools_app/src/network/flutter/network_model.dart';
import 'package:devtools_app/src/network/flutter/network_screen.dart';
import 'package:devtools_app/src/http/http.dart';
import 'package:devtools_app/src/http/http_request_data.dart';
import 'package:devtools_app/src/network/network_controller.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/ui/fake_flutter/_real_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import '../support/mocks.dart';
import '../support/utils.dart';
import 'wrappers.dart';

NetworkController controller = NetworkController();

Future<void> pumpNetworkScreen(WidgetTester tester) async {
  await tester.pumpWidget(wrapWithControllers(
    const NetworkScreenBody(),
    network: controller,
  ));
  final finder = find.byType(NetworkScreenBody);
  expect(finder, findsOneWidget);
}

/// Clears the timeouts created when calling getHttpTimelineLogging and
/// setHttpTimelineLogging RPCs.
Future<void> clearTimeouts(WidgetTester tester) async =>
    await tester.pumpAndSettle(const Duration(seconds: 5));

void main() {
  FakeServiceManager fakeServiceManager;
  Timeline timeline;

  const windowSize = Size(1599.0, 1000.0);

  setUpAll(() async => timeline = await loadNetworkProfileTimeline());

  group('Network Profiler', () {
    setUp(() async {
      fakeServiceManager =
          FakeServiceManager(useFakeService: true, timelineData: timeline);
      (fakeServiceManager.service as FakeVmService)
          .httpEnableTimelineLoggingResult = false;
      setGlobal(ServiceConnectionManager, fakeServiceManager);
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithControllers(
        Builder(builder: const NetworkScreen().buildTab),
        network: NetworkController(),
      ));
      expect(find.text('Network'), findsOneWidget);
    });

    testWidgetsWithWindowSize('starts and stops', windowSize, (
      WidgetTester tester,
    ) async {
      controller = NetworkController();
      await pumpNetworkScreen(tester);

      // Ensure we're not recording initially.
      expect(controller.isPolling, false);
      expect(controller.recordingNotifier.value, false);

      // Start recording.
      await tester.tap(find.byKey(NetworkScreen.recordButtonKey));
      await tester.pump();

      // Check that we're polling.
      expect(controller.isPolling, true);
      expect(controller.recordingNotifier.value, true);

      // Stop recording.
      await tester.tap(find.byKey(NetworkScreen.stopButtonKey));
      await tester.pump();

      // Check that we've stopped polling.
      expect(controller.isPolling, false);
      expect(controller.recordingNotifier.value, false);

      await clearTimeouts(tester);
    });

    Future<void> loadRequestsAndCheck(WidgetTester tester) async {
      final splitFinder = find.byType(Split);

      // We're not recording; only expect the instructions and buttons to be
      // visible.
      expect(splitFinder, findsNothing);
      expect(find.byKey(NetworkScreen.recordButtonKey), findsOneWidget);
      expect(find.byKey(NetworkScreen.stopButtonKey), findsOneWidget);
      expect(find.byKey(NetworkScreen.clearButtonKey), findsOneWidget);
      expect(
        find.byKey(NetworkScreen.recordingInstructionsKey),
        findsOneWidget,
      );

      // Start recording but don't advance the clock in order to check the
      // loading spinner is displayed before requests are populated.
      await tester.tap(find.byKey(NetworkScreen.recordButtonKey));
      await tester.pump();

      expect(splitFinder, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Advance the clock to populate the HTTP requests table.
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    }

    testWidgetsWithWindowSize('builds proper content for state', windowSize,
        (WidgetTester tester) async {
      controller = NetworkController();
      await pumpNetworkScreen(tester);

      await loadRequestsAndCheck(tester);

      final PaginatedDataTable table =
          tester.widget(find.byType(PaginatedDataTable).first);
      final HttpRequestDataTableSource tableSource = table.source;

      // We should see the list of requests and the inspector, but have no
      // selected request.
      void expectNoSelection() {
        expect(find.byType(PaginatedDataTable), findsOneWidget);
        expect(find.byType(HttpRequestInspector), findsOneWidget);
        expect(tableSource.selectedRowCount, 0);
        expect(
          find.byKey(HttpRequestInspector.noRequestSelectedKey),
          findsOneWidget,
        );
      }

      expectNoSelection();

      Future<void> validateHeadersTab(HttpRequestData data) async {
        // Switch to headers tab.
        await tester.tap(find.byKey(HttpRequestInspector.headersTabKey));
        await tester.pumpAndSettle();

        expect(find.byType(HttpRequestHeadersView), findsOneWidget);
        expect(find.byType(HttpRequestTimingView), findsNothing);
        expect(find.byType(HttpRequestCookiesView), findsNothing);

        // There should be three tiles: general, response headers, and request
        // headers.
        expect(find.byType(ExpansionTile), findsNWidgets(3));

        // Check contents of general.
        final ExpansionTile generalTile =
            tester.widget(find.byKey(HttpRequestHeadersView.generalKey));

        final numGeneralEntries = data.general.length;
        expect(generalTile.children.length, numGeneralEntries);

        // Check contents of request headers.
        final ExpansionTile requestsTile =
            tester.widget(find.byKey(HttpRequestHeadersView.requestHeadersKey));
        final numRequestHeaders = data.requestHeaders.length;
        expect(requestsTile.children.length, numRequestHeaders);

        // Check contents of response headers.
        final ExpansionTile responsesTile = tester
            .widget(find.byKey(HttpRequestHeadersView.responseHeadersKey));
        final numResponseHeaders = data.responseHeaders.length;
        expect(responsesTile.children.length, numResponseHeaders);
      }

      Future<void> validateTimingTab(HttpRequestData data) async {
        // Switch to timing tab.
        await tester.tap(find.byKey(HttpRequestInspector.timingTabKey));
        await tester.pumpAndSettle();

        expect(find.byType(HttpRequestHeadersView), findsNothing);
        expect(find.byType(HttpRequestTimingView), findsOneWidget);
        expect(find.byType(HttpRequestCookiesView), findsNothing);

        // There should be a tile for each of the instant events, plus the
        // total duration.
        expect(
          find.byType(ExpansionTile),
          findsNWidgets(data.instantEvents.length + 1),
        );
      }

      Future<void> validateCookiesTab(HttpRequestData data) async {
        final hasCookies =
            tableSource.currentSelectionListenable.value.hasCookies;

        if (hasCookies) {
          // Switch to cookies tab.
          await tester.tap(find.byKey(HttpRequestInspector.cookiesTabKey));
          await tester.pumpAndSettle();

          expect(find.byType(HttpRequestHeadersView), findsNothing);
          expect(find.byType(HttpRequestTimingView), findsNothing);
          expect(find.byType(HttpRequestCookiesView), findsOneWidget);

          // Checks the contents of a cookies table to ensure it's well formed.
          void validateCookieTable(List<Cookie> cookies, Key key) {
            expect(
              find.byKey(key),
              findsOneWidget,
            );
            final cookieCount = cookies.length;
            final DataTable cookiesTable = tester.widget(
              find.byKey(key),
            );
            expect(cookiesTable.rows.length, cookieCount);
          }

          // Check the request cookies table.
          if (data.requestCookies.isNotEmpty) {
            validateCookieTable(
              data.requestCookies,
              HttpRequestCookiesView.requestCookiesKey,
            );
          }

          // Check the response cookies table.
          if (data.responseCookies.isNotEmpty) {
            validateCookieTable(
              data.responseCookies,
              HttpRequestCookiesView.responseCookiesKey,
            );
          }
        } else {
          // The cookies tab shouldn't be displayed if there are no cookies
          // associated with the request.
          expect(find.byKey(HttpRequestInspector.cookiesTabKey), findsNothing);
        }
      }

      // Note: we only iterate over the first 25 rows as that's what's displayed
      // by in the table.
      for (final row in find
          .byKey(HttpRequestDataTableSource.httpRequestRowKey)
          .evaluate()) {
        // Tap a row and ensure the inspector is populated.
        await tester.tap(find.byWidget(row.widget));
        await tester.pumpAndSettle();
        expect(
          find.byKey(HttpRequestInspector.noRequestSelectedKey),
          findsNothing,
        );

        final selection = tableSource.currentSelectionListenable.value;
        await validateHeadersTab(selection);
        await validateTimingTab(selection);
        await validateCookiesTab(selection);
      }

      // Clear the selection (select + deselect a known entry).
      for (int i = 0; i < 2; ++i) {
        await tester.tap(
          find.byKey(HttpRequestDataTableSource.httpRequestRowKey).first,
        );
        await tester.pumpAndSettle();
      }

      // After de-selecting the last selected row, the inspector should not be
      // displaying anything.
      expectNoSelection();

      await clearTimeouts(tester);
    });

    testWidgetsWithWindowSize('clear results', windowSize,
        (WidgetTester tester) async {
      // Load the network profiler screen.
      controller = NetworkController();
      await pumpNetworkScreen(tester);

      // Populate the screen with requests.
      await loadRequestsAndCheck(tester);

      // Stop the profiler.
      await tester.tap(find.byKey(NetworkScreen.stopButtonKey));
      await tester.pumpAndSettle();

      // Clear the results.
      await tester.tap(find.byKey(NetworkScreen.clearButtonKey));
      await tester.pumpAndSettle();

      // Ensure that the recording instructions are displayed when no requests
      // are displayed and recording is disabled.
      expect(find.byType(PaginatedDataTable), findsNothing);
      expect(find.byType(HttpRequestInspector), findsNothing);
      expect(
        find.byKey(NetworkScreen.recordingInstructionsKey),
        findsOneWidget,
      );
    });
  });
}
