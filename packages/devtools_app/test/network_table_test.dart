// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:devtools_app/src/http/http_request_data.dart';
import 'package:devtools_app/src/screens/network/network_controller.dart';
import 'package:devtools_app/src/screens/network/network_model.dart';
import 'package:devtools_app/src/screens/network/network_screen.dart';
import 'package:devtools_app/src/service/service_manager.dart';
@TestOn('vm')
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/version.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import 'test_data/network_test_data.dart';
import 'test_utils/network_test_utils.dart';

void main() {
  group('NetworkScreen NetworkRequestsTable - Dart IO 1.6', () {
    late NetworkController controller;
    late FakeServiceManager fakeServiceManager;
    late SocketProfile socketProfile;
    late HttpProfile httpProfile;
    late List<NetworkRequest> requests;

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

      final pendingRequest = _findRequestById(7);
      expect(column.getDisplayValue(pendingRequest), '--');
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

      final pendingRequest = _findRequestById(7);
      expect(column.getDisplayValue(pendingRequest), 'Pending');
    });

    test('TimestampColumn', () {
      final column = TimestampColumn();
      final getRequest = _findRequestById(1);

      // The hours field may be unreliable since it depends on the timezone the
      // test is running in.
      expect(column.getDisplayValue(getRequest), contains(':45:26.279'));
    });
  });
}
