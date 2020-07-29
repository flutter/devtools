// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/http/http_request_data.dart';
import 'package:devtools_app/src/network/network_controller.dart';
import 'package:devtools_app/src/network/network_model.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart';

import 'support/mocks.dart';
import 'support/utils.dart';

void main() {
  group('NetworkController', () {
    NetworkController controller;
    FakeServiceManager fakeServiceManager;
    Timeline timeline;
    SocketProfile socketProfile;

    setUpAll(() async {
      timeline = await loadNetworkProfileTimeline();
      socketProfile = loadSocketProfile();
    });

    setUp(() {
      fakeServiceManager = FakeServiceManager(
        useFakeService: true,
        timelineData: timeline,
        socketProfile: socketProfile,
      );
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      controller = NetworkController();
    });

    test('initialize recording state', () async {
      expect(controller.isPolling, false);

      // Fake service pretends HTTP timeline logging is always enabled.
      await controller.addClient();
      expect(controller.isPolling, true);
      controller.removeClient();
    });

    test('start and pause recording', () async {
      expect(controller.isPolling, false);
      final notifier = controller.recordingNotifier;
      await addListenerScope(
        listenable: notifier,
        listener: () {
          expect(notifier.value, true);
          expect(controller.isPolling, true);
        },
        callback: () async {
          await controller.addClient();
          await controller.startRecording();
        },
      );

      await addListenerScope(
        listenable: notifier,
        listener: () {
          expect(notifier.value, false);
          expect(controller.isPolling, false);
        },
        callback: () async => await controller.stopRecording(),
      );

      await addListenerScope(
        listenable: notifier,
        listener: () {
          expect(notifier.value, true);
          expect(controller.isPolling, true);
        },
        callback: () async => await controller.startRecording(),
      );
      controller.removeClient();
    });

    test('process network data', () async {
      await controller.addClient();
      final requestsNotifier = controller.requests;
      NetworkRequests profile = requestsNotifier.value;
      // Check profile is initially empty.
      expect(profile.requests.isEmpty, true);
      expect(profile.outstandingHttpRequests.isEmpty, true);

      // The number of valid requests recorded in the test data.
      const numRequests = 71;

      // Refresh network data and ensure requests are populated.
      await controller.networkService.refreshNetworkData();
      profile = requestsNotifier.value;
      expect(profile.requests.length, numRequests);

      expect(profile.outstandingHttpRequests.isEmpty, true);

      const httpMethods = <String>{
        'CONNECT',
        'DELETE',
        'GET',
        'HEAD',
        'PATCH',
        'POST',
        'PUT',
      };

      final List<HttpRequestData> httpRequests = profile.requests
          .where((r) => r is HttpRequestData)
          .cast<HttpRequestData>()
          .toList();
      for (final request in httpRequests) {
        expect(request.duration, isNotNull);
        expect(request.general, isNotNull);
        expect(request.general.length, greaterThan(0));
        expect(request.hasCookies, isNotNull);
        expect(request.inProgress, false);
        expect(request.instantEvents, isNotNull);
        expect(httpMethods.contains(request.method), true);
        expect(request.requestCookies, isNotNull);
        expect(request.responseCookies, isNotNull);
        expect(request.startTimestamp, isNotNull);
        expect(request.status, isNotNull);
        expect(request.uri, isNotNull);
      }

      // Finally, call `clear()` and ensure the requests have been cleared.
      await controller.clear();
      profile = requestsNotifier.value;
      expect(profile.requests.isEmpty, true);
      expect(profile.outstandingHttpRequests.isEmpty, true);
      controller.removeClient();
    });
  });
}
