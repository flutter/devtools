// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/http/http_request_data.dart';
import 'package:devtools_app/src/network/flutter/network_screen.dart';
import 'package:devtools_app/src/network/network_controller.dart';
import 'package:test/test.dart';

import '../support/utils.dart';

void main() {
  group('NetworkScreen HttpRequestsTable', () {
    List<HttpRequestData> requests;

    setUpAll(() async {
      final timeline = await loadNetworkProfileTimeline();
      // Remove the last end event.
      timeline.traceEvents =
          timeline.traceEvents.sublist(0, timeline.traceEvents.length - 1);
      final httpRequests = NetworkController.processHttpTimelineEventsHelper(
        timeline,
        0,
        currentValues: [],
        invalidRequests: [],
        outstandingRequestsMap: {},
      );
      requests = httpRequests.requests;
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

    test('StatusColumn', () {
      final column = StatusColumn();
      var request = requests.first;

      expect(column.getDisplayValue(request), request.status);

      request = requests.firstWhere((r) => r.inProgress);
      expect(column.getDisplayValue(request), '--');
    });

    test('DurationColumn', () {
      final column = StatusColumn();
      var request = requests.first;

      expect(column.getDisplayValue(request), '200');

      request = requests.firstWhere((r) => r.inProgress);
      expect(column.getDisplayValue(request), '--');
    });

    test('TimestampColumn', () {
      final column = TimestampColumn();
      final request = requests.first;

      // The hours field may be unreliable since it depends on the timezone the
      // test is running in.
      expect(column.getDisplayValue(request), contains(':25:34.126'));

      expect(TimestampColumn.formatRequestTime(DateTime(2020, 1, 16, 13)),
          '1:00:00.000 PM');
    });
  });
}
