// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/http/http_request_data.dart';
import 'package:devtools_app/src/network/network_controller.dart';
import 'package:devtools_app/src/network/network_model.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/ui/filter.dart';
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

    setUp(() async {
      timeline = await loadNetworkProfileTimeline();
      socketProfile = loadSocketProfile();
      fakeServiceManager = FakeServiceManager(
        service: FakeServiceManager.createFakeService(
          timelineData: timeline,
          socketProfile: socketProfile,
        ),
      );
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      controller = NetworkController();
    });

    test('initialize recording state', () async {
      expect(controller.isPolling, false);

      // Fake service pretends HTTP timeline logging and socket profiling are
      // always enabled.
      await controller.startRecording();
      expect(controller.isPolling, true);
      controller.stopRecording();
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
          await controller.startRecording();
        },
      );

      // Pause polling.
      controller.togglePolling(false);
      expect(notifier.value, false);
      expect(controller.isPolling, false);

      // Resume polling.
      controller.togglePolling(true);
      expect(notifier.value, true);
      expect(controller.isPolling, true);

      controller.stopRecording();
      expect(notifier.value, false);
      expect(controller.isPolling, false);
    });

    test('process network data', () async {
      await controller.startRecording();
      final requestsNotifier = controller.requests;
      NetworkRequests profile = requestsNotifier.value;
      // Check profile is initially empty.
      expect(profile.requests.isEmpty, true);
      expect(profile.outstandingHttpRequests.isEmpty, true);

      // The number of valid requests recorded in the test data.
      const numRequests = 16;

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
      controller.stopRecording();
    });

    test('matchesForSearch', () async {
      // The number of valid requests recorded in the test data.
      const numRequests = 16;

      final requestsNotifier = controller.requests;
      // Refresh network data and ensure requests are populated.
      await controller.networkService.refreshNetworkData();
      final profile = requestsNotifier.value;
      expect(profile.requests.length, numRequests);

      expect(controller.matchesForSearch('year=2019').length, equals(5));
      expect(controller.matchesForSearch('127.0.0.1').length, equals(14));
      expect(controller.matchesForSearch('IPv6').length, equals(2));
      expect(controller.matchesForSearch('').length, equals(0));

      // Search with incorrect case.
      expect(controller.matchesForSearch('YEAR').length, equals(5));
    });

    test('filterData', () async {
      // The number of valid requests recorded in the test data.
      const numRequests = 16;

      final requestsNotifier = controller.requests;
      // Refresh network data and ensure requests are populated.
      await controller.networkService.refreshNetworkData();
      final profile = requestsNotifier.value;

      for (final r in profile.requests) {
        print('${r.uri}, ${r.method}, ${r.status}, ${r.type}');
      }

      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(numRequests));

      controller
          .filterData(QueryFilter.parse('127.0.0.1', controller.filterArgs));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(14));

      controller.filterData(QueryFilter.parse('', controller.filterArgs));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(numRequests));

      controller
          .filterData(QueryFilter.parse('method:put', controller.filterArgs));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(2));

      controller.filterData(QueryFilter.parse('m:head', controller.filterArgs));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(2));

      controller
          .filterData(QueryFilter.parse('-method:put', controller.filterArgs));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(14));

      controller
          .filterData(QueryFilter.parse('status:Error', controller.filterArgs));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(7));

      controller.filterData(QueryFilter.parse('s:101', controller.filterArgs));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(2));

      controller
          .filterData(QueryFilter.parse('-s:Error', controller.filterArgs));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(9));

      controller
          .filterData(QueryFilter.parse('type:http', controller.filterArgs));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(7));

      controller.filterData(QueryFilter.parse('t:ws', controller.filterArgs));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(2));

      controller.filterData(QueryFilter.parse('-t:ws', controller.filterArgs));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(14));

      controller.filterData(QueryFilter.parse('-', controller.filterArgs));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(0));

      controller
          .filterData(QueryFilter.parse('nonsense', controller.filterArgs));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(0));

      controller
          .filterData(QueryFilter.parse('-nonsense', controller.filterArgs));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(0));

      controller.filterData(null);
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(numRequests));

      controller
          .filterData(QueryFilter.parse('-t:ws,http', controller.filterArgs));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(7));

      controller.filterData(
          QueryFilter.parse('-t:ws,http method:put', controller.filterArgs));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(1));

      controller.filterData(
          QueryFilter.parse('-status:error method:get', controller.filterArgs));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(3));

      controller.filterData(QueryFilter.parse(
          '-status:error method:get t:conf', controller.filterArgs));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(1));
    });
  });
}
