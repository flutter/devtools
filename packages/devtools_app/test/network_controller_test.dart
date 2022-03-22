// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

@TestOn('vm')

import 'package:devtools_app/src/http/http_request_data.dart';
import 'package:devtools_app/src/screens/network/network_controller.dart';
import 'package:devtools_app/src/screens/network/network_model.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/ui/filter.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import 'test_utils/network_test_utils.dart';

void main() {
  group('NetworkController', () {
    late NetworkController controller;
    late FakeServiceManager fakeServiceManager;
    late SocketProfile socketProfile;
    late HttpProfile httpProfile;

    setUp(() async {
      socketProfile = loadSocketProfile();
      httpProfile = loadHttpProfile();
      fakeServiceManager = FakeServiceManager(
        service: FakeServiceManager.createFakeService(
          socketProfile: socketProfile,
          httpProfile: httpProfile,
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
      expect(profile.outstandingHttpRequests.isEmpty, false);
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
      expect(profile.outstandingHttpRequests.isEmpty, true);
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

      for (final r in profile.requests) {
        print('${r.uri}, ${r.method}, ${r.status}, ${r.type}');
      }

      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(numRequests));

      controller.filterData(Filter(
        queryFilter: QueryFilter.parse(
          'jsonplaceholder',
          controller.filterArgs,
        ),
      ));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(5));

      controller.filterData(
          Filter(queryFilter: QueryFilter.parse('', controller.filterArgs)));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(numRequests));

      controller.filterData(Filter(
          queryFilter: QueryFilter.parse('method:get', controller.filterArgs)));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(6));

      controller.filterData(Filter(
          queryFilter: QueryFilter.parse('m:put', controller.filterArgs)));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(1));

      controller.filterData(Filter(
          queryFilter:
              QueryFilter.parse('-method:put', controller.filterArgs)));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(8));

      controller.filterData(Filter(
          queryFilter:
              QueryFilter.parse('status:Error', controller.filterArgs)));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(1));

      controller.filterData(Filter(
          queryFilter: QueryFilter.parse('s:101', controller.filterArgs)));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(3));

      controller.filterData(Filter(
          queryFilter: QueryFilter.parse('-s:Error', controller.filterArgs)));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(8));

      controller.filterData(Filter(
          queryFilter: QueryFilter.parse('type:json', controller.filterArgs)));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(4));

      controller.filterData(Filter(
          queryFilter: QueryFilter.parse('t:ws', controller.filterArgs)));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(2));

      controller.filterData(Filter(
          queryFilter: QueryFilter.parse('-t:ws', controller.filterArgs)));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(7));

      controller.filterData(
          Filter(queryFilter: QueryFilter.parse('-', controller.filterArgs)));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(0));

      controller.filterData(Filter(
          queryFilter: QueryFilter.parse('nonsense', controller.filterArgs)));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(0));

      controller.filterData(Filter(
          queryFilter: QueryFilter.parse('-nonsense', controller.filterArgs)));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(0));

      controller.filterData(null);
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(numRequests));

      controller.filterData(Filter(
          queryFilter: QueryFilter.parse('-t:ws,http', controller.filterArgs)));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(4));

      controller.filterData(Filter(
          queryFilter: QueryFilter.parse(
              '-t:ws,http method:put', controller.filterArgs)));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(1));

      controller.filterData(Filter(
          queryFilter: QueryFilter.parse(
              '-status:error method:get', controller.filterArgs)));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(5));

      controller.filterData(Filter(
          queryFilter: QueryFilter.parse(
              '-status:error method:get t:http', controller.filterArgs)));
      expect(profile.requests, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(2));
    });
  });
}
