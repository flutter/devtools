// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/network/network_request_inspector.dart';
import 'package:devtools_app/src/screens/network/network_request_inspector_views.dart';
import 'package:devtools_app/src/shared/http/http.dart';
import 'package:devtools_app/src/shared/ui/tab.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import '../test_infra/test_data/network.dart';
import 'utils/network_test_utils.dart';

NetworkController controller = NetworkController();
DebuggerController debugController = DebuggerController();

Future<void> pumpNetworkScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    wrapWithControllers(
      const NetworkScreenBody(),
      network: controller,
      debugger: debugController,
    ),
  );
  final finder = find.byType(NetworkScreenBody);
  expect(finder, findsOneWidget);
}

/// Clears the timeouts created when calling getHttpTimelineLogging and
/// setHttpTimelineLogging RPCs.
Future<void> clearTimeouts(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

void main() {
  late FakeServiceConnectionManager fakeServiceConnection;
  late SocketProfile socketProfile;
  late HttpProfile httpProfile;

  const windowSize = Size(1599.0, 1000.0);

  setUpAll(() {
    socketProfile = loadSocketProfile();
    httpProfile = loadHttpProfile();
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(NotificationService, NotificationService());
    setGlobal(BreakpointManager, BreakpointManager());
  });

  group('Network Profiler', () {
    setUp(() {
      fakeServiceConnection = FakeServiceConnectionManager(
        service: FakeServiceManager.createFakeService(
          socketProfile: socketProfile,
          httpProfile: httpProfile,
        ),
      );
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
    });

    testWidgetsWithWindowSize('starts and stops', windowSize, (
      WidgetTester tester,
    ) async {
      controller = NetworkController();

      // Ensure we're not recording initially.
      expect(controller.isPolling, false);
      expect(controller.recordingNotifier.value, false);

      await pumpNetworkScreen(tester);
      await tester.pumpAndSettle();

      // Check that we're polling.
      expect(controller.isPolling, true);
      expect(controller.recordingNotifier.value, true);

      // Pause recording.
      expect(find.byType(PauseButton), findsOneWidget);
      await tester.tap(find.byType(PauseButton));
      await tester.pumpAndSettle();

      // Check that we've stopped polling.
      expect(controller.isPolling, false);
      expect(controller.recordingNotifier.value, false);

      await clearTimeouts(tester);
    });

    Future<void> loadRequestsAndCheck(WidgetTester tester) async {
      expect(find.byType(ResumeButton), findsOneWidget);
      expect(find.byType(PauseButton), findsOneWidget);
      expect(find.byType(ClearButton), findsOneWidget);
      expect(find.byType(Split), findsOneWidget);

      // Advance the clock to populate the network requests table.
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(CircularProgressIndicator), findsNothing);

      expect(controller.requests.value.requests, isNotEmpty);
    }

    // We should see the list of requests and the inspector, but have no
    // selected request.
    void expectNoSelection() {
      expect(find.byType(NetworkRequestsTable), findsOneWidget);
      expect(find.byType(NetworkRequestInspector), findsOneWidget);
      expect(find.text('No request selected'), findsOneWidget);
      expect(controller.selectedRequest.value, isNull);
    }

    testWidgetsWithWindowSize(
      'builds proper content for state',
      windowSize,
      (WidgetTester tester) async {
        controller = NetworkController();
        await pumpNetworkScreen(tester);

        await loadRequestsAndCheck(tester);

        expectNoSelection();

        Future<void> validateHeadersTab(DartIOHttpRequestData data) async {
          // Switch to headers tab.
          await tester.tap(
            find.descendant(
              of: find.byType(DevToolsTab),
              matching: find.text('Headers'),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(NetworkRequestOverviewView), findsNothing);
          expect(find.byType(HttpRequestHeadersView), findsOneWidget);
          expect(find.byType(HttpResponseView), findsNothing);
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
          final ExpansionTile requestsTile = tester
              .widget(find.byKey(HttpRequestHeadersView.requestHeadersKey));
          final numRequestHeaders = data.requestHeaders?.length ?? 0;
          expect(requestsTile.children.length, numRequestHeaders);

          // Check contents of response headers.
          final ExpansionTile responsesTile = tester
              .widget(find.byKey(HttpRequestHeadersView.responseHeadersKey));
          final numResponseHeaders = data.responseHeaders?.length ?? 0;
          expect(responsesTile.children.length, numResponseHeaders);
        }

        Future<void> validateResponseTab(DartIOHttpRequestData data) async {
          if (data.responseBody != null) {
            // Switch to response tab.
            await tester.tap(
              find.descendant(
                of: find.byType(DevToolsTab),
                matching: find.text('Response'),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.byType(HttpResponseTrailingDropDown), findsOneWidget);
            expect(find.byType(HttpViewTrailingCopyButton), findsOneWidget);
            expect(find.byType(NetworkRequestOverviewView), findsNothing);
            expect(find.byType(HttpRequestHeadersView), findsNothing);
            expect(find.byType(HttpResponseView), findsOneWidget);
            expect(find.byType(HttpRequestCookiesView), findsNothing);
          }
        }

        Future<void> validateOverviewTab() async {
          // Switch to overview tab.
          await tester.tap(
            find.descendant(
              of: find.byType(DevToolsTab),
              matching: find.text('Overview'),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(NetworkRequestOverviewView), findsOneWidget);
          expect(find.byType(HttpRequestHeadersView), findsNothing);
          expect(find.byType(HttpResponseView), findsNothing);
          expect(find.byType(HttpRequestCookiesView), findsNothing);
        }

        Future<void> validateCookiesTab(DartIOHttpRequestData data) async {
          final httpRequest =
              controller.selectedRequest.value as DartIOHttpRequestData;
          final hasCookies = httpRequest.hasCookies;

          if (hasCookies) {
            // Switch to cookies tab.
            await tester.tap(
              find.descendant(
                of: find.byType(DevToolsTab),
                matching: find.text('Cookies'),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.byType(NetworkRequestOverviewView), findsNothing);
            expect(find.byType(HttpRequestHeadersView), findsNothing);
            expect(find.byType(HttpResponseView), findsNothing);
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
              find.descendant(
                of: find.byType(DevToolsTab),
                matching: find.text('Cookies'),
              ),
              findsNothing,
            );
          }
        }

        for (final request in controller.requests.value.requests) {
          controller.selectedRequest.value = request;
          await tester.pumpAndSettle();
          expect(find.text('No request selected'), findsNothing);

          final selection = controller.selectedRequest.value!;
          if (selection is DartIOHttpRequestData) {
            await validateHeadersTab(selection);
            await validateResponseTab(selection);
            await validateCookiesTab(selection);
          }
          await validateOverviewTab();
        }

        // Pause recording.
        await tester.tap(find.byType(PauseButton));
        await tester.pump();

        await clearTimeouts(tester);
      },
    );

    // Regression test for https://github.com/flutter/devtools/issues/3286.
    testWidgetsWithWindowSize(
      'can select by clicking on url',
      windowSize,
      (WidgetTester tester) async {
        // Load the network profiler screen.
        controller = NetworkController();
        await pumpNetworkScreen(tester);

        // Populate the screen with requests.
        await loadRequestsAndCheck(tester);

        expectNoSelection();

        final textElement = tester.element(
          find.text('https://jsonplaceholder.typicode.com/albums/1').first,
        );
        final selectableTextWidget =
            textElement.findAncestorWidgetOfExactType<SelectableText>()!;
        await tester.tap(find.byWidget(selectableTextWidget));
        await tester.pumpAndSettle();

        expect(controller.selectedRequest.value, isNotNull);
        expect(find.text('No request selected'), findsNothing);
      },
    );

    testWidgetsWithWindowSize(
      'clear results',
      windowSize,
      (WidgetTester tester) async {
        // Load the network profiler screen.
        controller = NetworkController();
        await pumpNetworkScreen(tester);

        // Populate the screen with requests.
        await loadRequestsAndCheck(tester);

        // Pause the profiler.
        await tester.tap(find.byType(PauseButton));
        await tester.pumpAndSettle();

        // Clear the results.
        await tester.tap(find.byType(ClearButton));
        // Wait to ensure all the timers have been cancelled.
        await tester.pumpAndSettle(const Duration(seconds: 2));
      },
    );
  });

  group('NetworkRequestOverviewView', () {
    Future<void> pumpView(WidgetTester tester, NetworkRequest data) async {
      final widget = wrap(NetworkRequestOverviewView(data));
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      expect(find.byType(NetworkRequestOverviewView), findsOneWidget);
    }

    testWidgetsWithWindowSize(
      'displays for http request',
      windowSize,
      (tester) async {
        final data = httpGet;
        await pumpView(tester, data);

        // Verify general information.
        expect(find.text('Request uri: '), findsOneWidget);
        expect(
          find.text('https://jsonplaceholder.typicode.com/albums/1'),
          findsOneWidget,
        );
        expect(find.text('Method: '), findsOneWidget);
        expect(find.text('GET'), findsOneWidget);
        expect(find.text('Status: '), findsOneWidget);
        expect(find.text('200'), findsOneWidget);
        expect(find.text('Port: '), findsOneWidget);
        expect(find.text('45648'), findsOneWidget);
        expect(find.text('Content type: '), findsOneWidget);
        expect(find.text('[application/json; charset=utf-8]'), findsOneWidget);

        // Verify timing information.
        expect(find.text('Timing: '), findsOneWidget);
        expect(find.text('Start time: '), findsOneWidget);
        expect(find.text(formatDateTime(data.startTimestamp)), findsOneWidget);
        expect(find.text('End time: '), findsOneWidget);
        expect(find.text(formatDateTime(data.endTimestamp!)), findsOneWidget);
        expect(
          find.byKey(NetworkRequestOverviewView.httpTimingGraphKey),
          findsOneWidget,
        );
        expect(find.text('Connection established: '), findsOneWidget);
        expect(
          find.text('[0.0 ms - 529.0 ms] → 529.0 ms total'),
          findsOneWidget,
        );
        expect(find.text('Request sent: '), findsOneWidget);
        expect(
          find.text('[529.0 ms - 529.0 ms] → 0.0 ms total'),
          findsOneWidget,
        );
        expect(find.text('Waiting (TTFB): '), findsOneWidget);
        expect(
          find.text('[529.0 ms - 810.7 ms] → 281.7 ms total'),
          findsOneWidget,
        );
        expect(find.text('Content Download: '), findsOneWidget);
        expect(
          find.text('[810.7 ms - 811.7 ms] → 1.0 ms total'),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithWindowSize(
      'displays for http request with error',
      windowSize,
      (tester) async {
        final data = httpGetWithError;
        await pumpView(tester, data);

        // Verify general information.
        expect(find.text('Request uri: '), findsOneWidget);
        expect(find.text('https://www.examplez.com/1'), findsOneWidget);
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
        expect(find.text(formatDateTime(data.endTimestamp!)), findsOneWidget);
        expect(
          find.byKey(NetworkRequestOverviewView.httpTimingGraphKey),
          findsOneWidget,
        );
        expect(find.text('Connection established: '), findsNothing);
        expect(find.text('Request sent: '), findsNothing);
        expect(find.text('Waiting (TTFB): '), findsNothing);
        expect(find.text('Content Download: '), findsNothing);
      },
    );

    testWidgetsWithWindowSize(
      'displays for closed web socket request',
      windowSize,
      (tester) async {
        final data = testSocket1;
        await pumpView(tester, data);

        // Verify general information.
        expect(find.text('Request uri: '), findsOneWidget);
        expect(
          find.text('InternetAddress(\'2606:4700:3037::ac43:bd8f\', IPv6)'),
          findsOneWidget,
        );
        expect(find.text('Method: '), findsOneWidget);
        expect(find.text('GET'), findsOneWidget);
        expect(find.text('Status: '), findsOneWidget);
        expect(find.text('101'), findsOneWidget);
        expect(find.text('Port: '), findsOneWidget);
        expect(find.text('443'), findsOneWidget);
        expect(find.text('Content type: '), findsOneWidget);
        expect(find.text('websocket'), findsOneWidget);
        expect(find.text('Socket id: '), findsOneWidget);
        expect(find.text('10000'), findsOneWidget);
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
        expect(find.text(formatDateTime(data.endTimestamp!)), findsOneWidget);
        expect(
          find.byKey(NetworkRequestOverviewView.socketTimingGraphKey),
          findsOneWidget,
        );
        expect(find.text('Last read time: '), findsOneWidget);
        expect(
          find.text(formatDateTime(data.lastReadTimestamp!)),
          findsOneWidget,
        );
        expect(find.text('Last write time: '), findsOneWidget);
        expect(
          find.text(formatDateTime(data.lastWriteTimestamp!)),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithWindowSize(
      'displays for open web socket request',
      windowSize,
      (tester) async {
        final data = testSocket2;
        await pumpView(tester, data);

        // Verify general information.
        expect(find.text('Request uri: '), findsOneWidget);
        expect(
          find.text('InternetAddress(\'2606:4700:3037::ac43:0000\', IPv6)'),
          findsOneWidget,
        );
        expect(find.text('Method: '), findsOneWidget);
        expect(find.text('GET'), findsOneWidget);
        expect(find.text('Status: '), findsOneWidget);
        expect(find.text('101'), findsOneWidget);
        expect(find.text('Port: '), findsOneWidget);
        expect(find.text('80'), findsOneWidget);
        expect(find.text('Content type: '), findsOneWidget);
        expect(find.text('websocket'), findsOneWidget);
        expect(find.text('Socket id: '), findsOneWidget);
        expect(find.text('11111'), findsOneWidget);
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
        expect(
          find.byKey(NetworkRequestOverviewView.socketTimingGraphKey),
          findsOneWidget,
        );
        expect(find.text('Last read time: '), findsOneWidget);
        expect(
          find.text(formatDateTime(data.lastReadTimestamp!)),
          findsOneWidget,
        );
        expect(find.text('Last write time: '), findsOneWidget);
        expect(
          find.text(formatDateTime(data.lastWriteTimestamp!)),
          findsOneWidget,
        );
      },
    );
  });
}
