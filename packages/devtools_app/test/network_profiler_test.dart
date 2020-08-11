// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/split.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/http/http.dart';
import 'package:devtools_app/src/http/http_request_data.dart';
import 'package:devtools_app/src/network/network_model.dart';
import 'package:devtools_app/src/network/network_request_inspector.dart';
import 'package:devtools_app/src/network/network_request_inspector_views.dart';
import 'package:devtools_app/src/network/network_screen.dart';
import 'package:devtools_app/src/network/network_controller.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import 'support/mocks.dart';
import 'support/network_test_data.dart';
import 'support/utils.dart';
import 'support/wrappers.dart';

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
Future<void> clearTimeouts(WidgetTester tester) async {
  return await tester.pumpAndSettle(const Duration(seconds: 1));
}

void main() {
  FakeServiceManager fakeServiceManager;
  Timeline timeline;
  SocketProfile socketProfile;

  const windowSize = Size(1599.0, 1000.0);

  setUpAll(() async {
    timeline = await loadNetworkProfileTimeline();
    socketProfile = loadSocketProfile();
  });

  group('Network Profiler', () {
    setUp(() async {
      fakeServiceManager = FakeServiceManager(
        useFakeService: true,
        timelineData: timeline,
        socketProfile: socketProfile,
      );
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

      // Start recording.
      await tester.tap(find.byKey(NetworkScreen.recordButtonKey));
      await tester.pump();

      expect(splitFinder, findsOneWidget);

      // Advance the clock to populate the network requests table.
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    }

    testWidgetsWithWindowSize('builds proper content for state', windowSize,
        (WidgetTester tester) async {
      controller = NetworkController();
      await pumpNetworkScreen(tester);

      await loadRequestsAndCheck(tester);

      // We should see the list of requests and the inspector, but have no
      // selected request.
      void expectNoSelection() {
        expect(find.byType(NetworkRequestsTable), findsOneWidget);
        expect(find.byType(NetworkRequestInspector), findsOneWidget);
        expect(
          find.byKey(NetworkRequestInspector.noRequestSelectedKey),
          findsOneWidget,
        );
      }

      expectNoSelection();

      Future<void> validateHeadersTab(HttpRequestData data) async {
        // Switch to headers tab.
        await tester.tap(find.byKey(NetworkRequestInspector.headersTabKey));
        await tester.pumpAndSettle();

        expect(find.byType(NetworkRequestOverviewView), findsNothing);
        expect(find.byType(HttpRequestHeadersView), findsOneWidget);
        expect(find.byType(HttpRequestCookiesView), findsNothing);

        // TODO(kenz): move the headers tab validation into its own testing
        // group (see NetworkRequestOverviewView test group).

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

      Future<void> validateOverviewTab(NetworkRequest data) async {
        // Switch to overview tab.
        await tester.tap(find.byKey(NetworkRequestInspector.overviewTabKey));
        await tester.pumpAndSettle();

        expect(find.byType(NetworkRequestOverviewView), findsOneWidget);
        expect(find.byType(HttpRequestHeadersView), findsNothing);
        expect(find.byType(HttpRequestCookiesView), findsNothing);
      }

      Future<void> validateCookiesTab(HttpRequestData data) async {
        final httpRequest = controller.selectedRequest.value as HttpRequestData;
        final hasCookies = httpRequest.hasCookies;

        if (hasCookies) {
          // Switch to cookies tab.
          await tester.tap(find.byKey(NetworkRequestInspector.cookiesTabKey));
          await tester.pumpAndSettle();

          expect(find.byType(NetworkRequestOverviewView), findsNothing);
          expect(find.byType(HttpRequestHeadersView), findsNothing);
          expect(find.byType(HttpRequestCookiesView), findsOneWidget);

          // TODO(kenz): move the cookie tab validation into its own testing
          // group (see NetworkRequestOverviewView test group).

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
          expect(
              find.byKey(NetworkRequestInspector.cookiesTabKey), findsNothing);
        }
      }

      // TODO(devoncarew): The tests don't pass if we try and test more than one
      // http request.
      for (final request in controller.requests.value.requests.sublist(0, 1)) {
        // Tap a row and ensure the inspector is populated.
        await tester.tap(find.byKey(ValueKey(request)));
        await tester.pumpAndSettle();
        expect(
          find.byKey(NetworkRequestInspector.noRequestSelectedKey),
          findsNothing,
        );

        final selection = controller.selectedRequest.value;
        if (selection is HttpRequestData) {
          await validateHeadersTab(selection);
          await validateCookiesTab(selection);
        }
        await validateOverviewTab(selection);
      }

      // Stop recording.
      await tester.tap(find.byKey(NetworkScreen.stopButtonKey));
      await tester.pump();

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
      // Wait to ensure all the timers have been cancelled.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Ensure that the recording instructions are displayed when no requests
      // are displayed and recording is disabled.
      expect(find.byType(PaginatedDataTable), findsNothing);
      expect(find.byType(NetworkRequestInspector), findsNothing);
      expect(
        find.byKey(NetworkScreen.recordingInstructionsKey),
        findsOneWidget,
      );
    });
  });

  group('NetworkRequestOverviewView', () {
    Future<void> pumpView(WidgetTester tester, NetworkRequest data) async {
      final widget = wrap(NetworkRequestOverviewView(data));
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      expect(find.byType(NetworkRequestOverviewView), findsOneWidget);
    }

    testWidgets('displays for http request', (tester) async {
      final data = httpGetEvent;
      await pumpView(tester, data);

      // Verify general information.
      expect(find.text('Request uri: '), findsOneWidget);
      expect(find.text('http://127.0.0.1:8011/foo/bar?foo=bar&year=2019'),
          findsOneWidget);
      expect(find.text('Method: '), findsOneWidget);
      expect(find.text('GET'), findsOneWidget);
      expect(find.text('Status: '), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(find.text('Port: '), findsOneWidget);
      expect(find.text('35248'), findsOneWidget);
      expect(find.text('Content type: '), findsOneWidget);
      expect(find.text('[text/plain; charset=utf-8]'), findsOneWidget);

      // Verify timing information.
      expect(find.text('Timing: '), findsOneWidget);
      expect(find.text('Start time: '), findsOneWidget);
      expect(find.text(formatDateTime(data.startTimestamp)), findsOneWidget);
      expect(find.text('End time: '), findsOneWidget);
      expect(find.text(formatDateTime(data.endTimestamp)), findsOneWidget);
      expect(find.byKey(NetworkRequestOverviewView.httpTimingGraphKey),
          findsOneWidget);
      expect(find.text('Connection established: '), findsOneWidget);
      expect(find.text('[0.0 ms - 100.0 ms] → 100.0 ms total'), findsOneWidget);
      expect(find.text('Request initiated: '), findsOneWidget);
      expect(
          find.text('[100.0 ms - 200.0 ms] → 100.0 ms total'), findsOneWidget);
      expect(find.text('Response received: '), findsOneWidget);
      expect(
          find.text('[200.0 ms - 400.0 ms] → 200.0 ms total'), findsOneWidget);
    });

    testWidgets('displays for http request with error', (tester) async {
      final data = httpGetEventWithError;
      await pumpView(tester, data);

      // Verify general information.
      expect(find.text('Request uri: '), findsOneWidget);
      expect(find.text('http://www.example.com/'), findsOneWidget);
      expect(find.text('Method: '), findsOneWidget);
      expect(find.text('GET'), findsOneWidget);
      expect(find.text('Status: '), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Port: '), findsNothing);
      expect(find.text('Content type: '), findsNothing);

      // Verify timing information.
      expect(find.text('Timing: '), findsOneWidget);
      expect(find.text('Start time: '), findsOneWidget);
      expect(find.text(formatDateTime(data.startTimestamp)), findsOneWidget);
      expect(find.text('End time: '), findsOneWidget);
      expect(find.text(formatDateTime(data.endTimestamp)), findsOneWidget);
      expect(find.byKey(NetworkRequestOverviewView.httpTimingGraphKey),
          findsOneWidget);
      expect(find.text('Connection established: '), findsNothing);
      expect(find.text('Request initiated: '), findsNothing);
      expect(find.text('Response received: '), findsNothing);
    });

    testWidgetsWithWindowSize(
        'displays for closed web socket request', windowSize, (tester) async {
      final data = testSocket1;
      await pumpView(tester, data);

      // Verify general information.
      expect(find.text('Request uri: '), findsOneWidget);
      expect(find.text('InternetAddress(\'2606:4700:3037::ac43:bd8f\', IPv6)'),
          findsOneWidget);
      expect(find.text('Method: '), findsOneWidget);
      expect(find.text('GET'), findsOneWidget);
      expect(find.text('Status: '), findsOneWidget);
      expect(find.text('101'), findsOneWidget);
      expect(find.text('Port: '), findsOneWidget);
      expect(find.text('443'), findsOneWidget);
      expect(find.text('Content type: '), findsOneWidget);
      expect(find.text('websocket'), findsOneWidget);
      expect(find.text('Socket id: '), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Socket type: '), findsOneWidget);
      expect(find.text('tcp'), findsOneWidget);
      expect(find.text('Read bytes: '), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('Write bytes: '), findsOneWidget);
      expect(find.text('15'), findsOneWidget);

      // Verify timing information.
      expect(find.text('Timing: '), findsOneWidget);
      expect(find.text('Start time: '), findsOneWidget);
      expect(find.text(formatDateTime(data.startTimestamp)), findsOneWidget);
      expect(find.text('End time: '), findsOneWidget);
      expect(find.text(formatDateTime(data.endTimestamp)), findsOneWidget);
      expect(find.byKey(NetworkRequestOverviewView.socketTimingGraphKey),
          findsOneWidget);
      expect(find.text('Last read time: '), findsOneWidget);
      expect(find.text(formatDateTime(data.lastReadTimestamp)), findsOneWidget);
      expect(find.text('Last write time: '), findsOneWidget);
      expect(
          find.text(formatDateTime(data.lastWriteTimestamp)), findsOneWidget);
    });

    testWidgetsWithWindowSize(
        'displays for open web socket request', windowSize, (tester) async {
      final data = testSocket2;
      await pumpView(tester, data);

      // Verify general information.
      expect(find.text('Request uri: '), findsOneWidget);
      expect(find.text('InternetAddress(\'2606:4700:3037::ac43:0000\', IPv6)'),
          findsOneWidget);
      expect(find.text('Method: '), findsOneWidget);
      expect(find.text('GET'), findsOneWidget);
      expect(find.text('Status: '), findsOneWidget);
      expect(find.text('101'), findsOneWidget);
      expect(find.text('Port: '), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
      expect(find.text('Content type: '), findsOneWidget);
      expect(find.text('websocket'), findsOneWidget);
      expect(find.text('Socket id: '), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Socket type: '), findsOneWidget);
      expect(find.text('tcp'), findsOneWidget);
      expect(find.text('Read bytes: '), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('Write bytes: '), findsOneWidget);
      expect(find.text('25'), findsOneWidget);

      // Verify timing information.
      expect(find.text('Timing: '), findsOneWidget);
      expect(find.text('Start time: '), findsOneWidget);
      expect(find.text(formatDateTime(data.startTimestamp)), findsOneWidget);
      expect(find.text('End time: '), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.byKey(NetworkRequestOverviewView.socketTimingGraphKey),
          findsOneWidget);
      expect(find.text('Last read time: '), findsOneWidget);
      expect(find.text(formatDateTime(data.lastReadTimestamp)), findsOneWidget);
      expect(find.text('Last write time: '), findsOneWidget);
      expect(
          find.text(formatDateTime(data.lastWriteTimestamp)), findsOneWidget);
    });
  });
}
