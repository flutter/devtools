// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/http/http_request_data.dart';
import 'package:devtools_app/src/network/network_model.dart';
import 'package:devtools_app/src/network/network_screen.dart';
import 'package:devtools_app/src/network/network_controller.dart';
import 'package:test/test.dart';

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
          .where((r) => r is HttpRequestData)
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
          requests.where((r) => r is WebSocket).cast<WebSocket>().toList();
      final request = webSockets.first;
      expect(column.getDisplayValue(request), '101');
    });

    test('TypeColumn for http request', () {
      final column = TypeColumn();
      final httpRequests = requests
          .where((r) => r is HttpRequestData)
          .cast<HttpRequestData>()
          .toList();
      final request = httpRequests.first;
      expect(column.getDisplayValue(request), 'http');
    });

    test('TypeColumn for web socket request', () {
      final column = TypeColumn();
      final webSockets =
          requests.where((r) => r is WebSocket).cast<WebSocket>().toList();
      final request = webSockets.first;
      expect(column.getDisplayValue(request), 'ws');
    });

    test('DurationColumn for http request', () {
      final column = DurationColumn();
      final httpRequests = requests
          .where((r) => r is HttpRequestData)
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
          requests.where((r) => r is WebSocket).cast<WebSocket>().toList();
      var request = webSockets.first;

      expect(column.getDisplayValue(request), '1000 ms');

      request = webSockets.firstWhere((r) => r.duration == null);
      expect(column.getDisplayValue(request), 'Pending');
    });

    test('TimestampColumn', () {
      final column = TimestampColumn();
      final request = requests.first;

      // The hours field may be unreliable since it depends on the timezone the
      // test is running in.
      expect(column.getDisplayValue(request), contains(':25:34.126'));
    });
  });
}
