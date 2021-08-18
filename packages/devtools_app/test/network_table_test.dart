// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/http/http_request_data.dart';
import 'package:devtools_app/src/network/network_controller.dart';
import 'package:devtools_app/src/network/network_model.dart';
import 'package:devtools_app/src/network/network_screen.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/version.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import 'support/mocks.dart';
import 'support/network_test_data.dart';
import 'support/utils.dart';

void main() {
  group('NetworkScreen NetworkRequestsTable', () {
    List<NetworkRequest> requests;
    NetworkController controller;

    setUpAll(() async {
      controller = NetworkController();
      final timeline = await loadNetworkProfileTimeline();
      final sockets = loadSocketProfile().sockets;
      // Remove the last end event.
      timeline.traceEvents =
          timeline.traceEvents.sublist(0, timeline.traceEvents.length - 1);
      final networkRequests = controller.processNetworkTrafficHelper(
        timeline,
        sockets,
        [],
        0,
        currentValues: [],
        invalidRequests: [],
        outstandingRequestsMap: {},
      );
      requests = networkRequests.requests;
    });

    test('UriColumn', () {
      final column = UriColumn();
      final request = requests.first;

      expect(column.getDisplayValue(request), request.uri.toString());
    });

    test('MethodColumn', () {
      final column = MethodColumn();
      final request = requests.first;

      expect(column.getDisplayValue(request), request.method);
    });

    test('StatusColumn for http request', () {
      final column = StatusColumn();
      final httpRequests = requests
          .whereType<HttpRequestData>()
          .cast<HttpRequestData>()
          .toList();
      var request = httpRequests.first;

      expect(column.getDisplayValue(request), request.status);

      request = httpRequests.firstWhere((r) => r.inProgress);
      expect(column.getDisplayValue(request), '--');
    });

    test('StatusColumn for web socket request', () {
      final column = StatusColumn();
      final webSockets =
          requests.whereType<WebSocket>().cast<WebSocket>().toList();
      final request = webSockets.first;
      expect(column.getDisplayValue(request), '101');
    });

    test('TypeColumn for http request', () {
      final column = TypeColumn();
      final httpRequests = requests
          .whereType<HttpRequestData>()
          .cast<HttpRequestData>()
          .toList();
      final request = httpRequests.first;
      expect(column.getDisplayValue(request), 'txt');
    });

    test('TypeColumn for web socket request', () {
      final column = TypeColumn();
      final webSockets =
          requests.whereType<WebSocket>().cast<WebSocket>().toList();
      final request = webSockets.first;
      expect(column.getDisplayValue(request), 'ws');
    });

    test('DurationColumn for http request', () {
      final column = DurationColumn();
      final httpRequests = requests
          .whereType<HttpRequestData>()
          .cast<HttpRequestData>()
          .toList();
      var request = httpRequests.first;

      expect(column.getDisplayValue(request), '228 ms');

      request = httpRequests.firstWhere((r) => r.inProgress);
      expect(column.getDisplayValue(request), 'Pending');
    });

    test('DurationColumn for web socket request', () {
      final column = DurationColumn();
      final webSockets =
          requests.whereType<WebSocket>().cast<WebSocket>().toList();
      var request = webSockets.first;

      expect(column.getDisplayValue(request), '1000 ms');

      request = webSockets.firstWhere((r) => r.duration == null);
      expect(column.getDisplayValue(request), 'Pending');
    });

    test('TimestampColumn', () {
      final column = TimestampColumn();
      final request = requests.firstWhere((e) => e is! WebSocket);
      // The hours field may be unreliable since it depends on the timezone the
      // test is running in.
      expect(column.getDisplayValue(request), contains(':25:34.126'));
    });
  });

  group('NetworkScreen NetworkRequestsTable - Dart IO 1.6', () {
    NetworkController controller;
    FakeServiceManager fakeServiceManager;
    SocketProfile socketProfile;
    HttpProfile httpProfile;
    List<NetworkRequest> requests;

    setUpAll(() async {
      httpProfile = loadHttpProfile();
      socketProfile = loadSocketProfile();
      fakeServiceManager = FakeServiceManager(
        service: FakeServiceManager.createFakeService(
          httpProfile: httpProfile,
          socketProfile: socketProfile,
        ),
      );
      // Create a fakeVmService because DartIOHttpRequestData.getFullRequestData needs one
      final fakeVmService = fakeServiceManager.service as FakeVmService;
      fakeVmService.dartIoVersion = SemanticVersion(major: 1, minor: 6);
      fakeVmService.httpEnableTimelineLoggingResult = false;
      setGlobal(ServiceConnectionManager, fakeServiceManager);

      // Bypass controller recording so timelineMicroOffset is not time dependant
      controller = NetworkController();
      final networkRequests = controller.processNetworkTrafficHelper(
        null,
        socketProfile.sockets,
        httpProfile.requests,
        0,
        currentValues: [],
        invalidRequests: [],
        outstandingRequestsMap: {},
      );
      requests = networkRequests.requests;
    });

    DartIOHttpRequestData _findRequestById(int id) {
      return requests
          .whereType<DartIOHttpRequestData>()
          .cast<DartIOHttpRequestData>()
          .firstWhere((request) => request.id == id);
    }

    test('UriColumn', () {
      final column = UriColumn();
      for (final request in requests) {
        expect(column.getDisplayValue(request), request.uri.toString());
      }
    });

    test('MethodColumn', () {
      final column = MethodColumn();
      for (final request in requests) {
        expect(column.getDisplayValue(request), request.method);
      }
    });

    test('StatusColumn for http request', () {
      final column = StatusColumn();
      final getRequest = _findRequestById(1);

      expect(column.getDisplayValue(getRequest), httpGet.status);

      // TODO(bleroux): add a pending request in test data
      // expect(column.getDisplayValue(request), '--');
    });

    test('TypeColumn for http request', () {
      final column = TypeColumn();
      final getRequest = _findRequestById(1);

      expect(column.getDisplayValue(getRequest), 'json');
    });

    test('DurationColumn for http request', () {
      final column = DurationColumn();
      final getRequest = _findRequestById(1);

      expect(column.getDisplayValue(getRequest), '811 ms');

      // TODO(bleroux): add a pending request in test data
      // expect(column.getDisplayValue(request), 'Pending');
    });

    test('TimestampColumn', () {
      final column = TimestampColumn();
      final getRequest = _findRequestById(1);
      print(httpGet.startTimestamp.toUtc());
      print(getRequest.startTimestamp.toUtc());

      // The hours field may be unreliable since it depends on the timezone the
      // test is running in.
      expect(column.getDisplayValue(getRequest), contains(':45:26.279'));
    });
  });
}
