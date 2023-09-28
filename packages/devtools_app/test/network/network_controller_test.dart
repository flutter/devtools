// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')

import 'package:devtools_app/src/screens/network/network_controller.dart';
import 'package:devtools_app/src/screens/network/network_model.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/http/http_request_data.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import 'utils/network_test_utils.dart';

void main() {
  group('NetworkController', () {
    late NetworkController controller;
    late FakeServiceConnectionManager fakeServiceConnection;
    late SocketProfile socketProfile;
    late HttpProfile httpProfile;

    setUp(() {
      socketProfile = loadSocketProfile();
      httpProfile = loadHttpProfile();
      fakeServiceConnection = FakeServiceConnectionManager(
        service: FakeServiceManager.createFakeService(
          socketProfile: socketProfile,
          httpProfile: httpProfile,
        ),
      );
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
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

      // The number of valid requests recorded in the test data.
      const numSockets = 2;
      const numHttpProfile = 7;
      const numRequests = numSockets + numHttpProfile;

      const httpMethods = <String>{
        'CONNECT',
        'DELETE',
        'GET',
        'HEAD',
        'PATCH',
        'POST',
        'PUT',
      };

      // Refresh network data and ensure requests are populated.
      await controller.networkService.refreshNetworkData();
      profile = requestsNotifier.value;
      expect(profile.requests.length, numRequests);
      final List<DartIOHttpRequestData> httpRequests = profile.requests
          .whereType<DartIOHttpRequestData>()
          .cast<DartIOHttpRequestData>()
          .toList();
      for (final request in httpRequests) {
        expect(request.duration, request.inProgress ? isNull : isNotNull);
        expect(request.general.length, greaterThan(0));
        expect(httpMethods.contains(request.method), true);
        expect(request.status, request.inProgress ? isNull : isNotNull);
      }

      // Finally, call `clear()` and ensure the requests have been cleared.
      await controller.clear();
      profile = requestsNotifier.value;
      expect(profile.requests.isEmpty, true);
      controller.stopRecording();
    });

    test('matchesForSearch', () async {
      await controller.startRecording();
      // The number of valid requests recorded in the test data.
      const numRequests = 9;

      final requestsNotifier = controller.requests;
      // Refresh network data and ensure requests are populated.
      await controller.networkService.refreshNetworkData();
      final profile = requestsNotifier.value;
      expect(profile.requests.length, numRequests);

      expect(controller.matchesForSearch('jsonplaceholder').length, equals(5));
      expect(controller.matchesForSearch('IPv6').length, equals(2));
      expect(controller.matchesForSearch('').length, equals(0));

      // Search with incorrect case.
      expect(controller.matchesForSearch('JSONPLACEHOLDER').length, equals(5));
    });

    test('matchesForSearch sets isSearchMatch property', () async {
      // The number of valid requests recorded in the test data.
      const numRequests = 9;

      await controller.startRecording();
      final requestsNotifier = controller.requests;
      // Refresh network data and ensure requests are populated.
      await controller.networkService.refreshNetworkData();
      final profile = requestsNotifier.value;
      expect(profile.requests.length, numRequests);

      controller.search = 'jsonplaceholder';
      List<NetworkRequest> matches = controller.searchMatches.value;
      expect(matches.length, equals(5));
      verifyIsSearchMatch(profile.requests, matches);

      controller.search = 'IPv6';
      matches = controller.searchMatches.value;
      expect(matches.length, equals(2));
      verifyIsSearchMatch(profile.requests, matches);
    });

    test('filterData', () async {
      await controller.startRecording();
      // The number of valid requests recorded in the test data.
      const numRequests = 9;

      final requestsNotifier = controller.requests;
      // Refresh network data and ensure requests are populated.
      await controller.networkService.refreshNetworkData();
      final profile = requestsNotifier.value;

      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(numRequests));

      controller.setActiveFilter(query: 'jsonplaceholder');
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(5));

      controller.setActiveFilter(query: '');
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(numRequests));

      controller.setActiveFilter(query: 'method:get');
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(6));

      controller.setActiveFilter(query: 'm:put');
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(1));

      controller.setActiveFilter(query: '-method:put');
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(8));

      controller.setActiveFilter(query: 'status:Error');
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(1));

      controller.setActiveFilter(query: 's:101');
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(3));

      controller.setActiveFilter(query: '-s:Error');
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(8));

      controller.setActiveFilter(query: 'type:json');
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(4));

      controller.setActiveFilter(query: 't:ws');
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(2));

      controller.setActiveFilter(query: '-t:ws');
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(7));

      controller.setActiveFilter(query: '-');
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(0));

      controller.setActiveFilter(query: 'nonsense');
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(0));

      controller.setActiveFilter(query: '-nonsense');
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(0));

      controller.setActiveFilter();
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(numRequests));

      controller.setActiveFilter(query: '-t:ws,http');
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(4));

      controller.setActiveFilter(query: '-t:ws,http method:put');
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(1));

      controller.setActiveFilter(query: '-status:error method:get');
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(5));

      controller.setActiveFilter(query: '-status:error method:get t:http');
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(2));
    });
  });
}
