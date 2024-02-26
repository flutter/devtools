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
import 'package:devtools_test/helpers.dart';
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
      List<NetworkRequest> requests = requestsNotifier.value;
      // Check profile is initially empty.
      expect(requests.isEmpty, true);

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
      requests = requestsNotifier.value;
      expect(requests.length, numRequests);
      final List<DartIOHttpRequestData> httpRequests = requests
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
      requests = requestsNotifier.value;
      expect(requests.isEmpty, true);
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
      expect(profile.length, numRequests);

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
      expect(profile.length, numRequests);

      controller.search = 'jsonplaceholder';
      List<NetworkRequest> matches = controller.searchMatches.value;
      expect(matches.length, equals(5));
      verifyIsSearchMatch(profile, matches);

      controller.search = 'IPv6';
      matches = controller.searchMatches.value;
      expect(matches.length, equals(2));
      verifyIsSearchMatch(profile, matches);
    });

    test('filterData', () async {
      await controller.startRecording();
      // The number of valid requests recorded in the test data.
      const numRequests = 9;

      final requestsNotifier = controller.requests;
      // Refresh network data and ensure requests are populated.
      await controller.networkService.refreshNetworkData();
      final profile = requestsNotifier.value;

      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(numRequests));

      controller.setActiveFilter(query: 'jsonplaceholder');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(5));

      controller.setActiveFilter(query: '');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(numRequests));

      controller.setActiveFilter(query: 'method:get');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(6));

      controller.setActiveFilter(query: 'm:put');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(1));

      controller.setActiveFilter(query: '-method:put');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(8));

      controller.setActiveFilter(query: 'status:Error');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(1));

      controller.setActiveFilter(query: 's:101');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(3));

      controller.setActiveFilter(query: '-s:Error');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(8));

      controller.setActiveFilter(query: 'type:json');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(4));

      controller.setActiveFilter(query: 't:ws');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(2));

      controller.setActiveFilter(query: '-t:ws');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(7));

      controller.setActiveFilter(query: '-');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(0));

      controller.setActiveFilter(query: 'nonsense');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(0));

      controller.setActiveFilter(query: '-nonsense');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(0));

      controller.setActiveFilter();
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(numRequests));

      controller.setActiveFilter(query: '-t:ws,http');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(4));

      controller.setActiveFilter(query: '-t:ws,http method:put');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(1));

      controller.setActiveFilter(query: '-status:error method:get');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(5));

      controller.setActiveFilter(query: '-status:error method:get t:http');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(2));
    });
  });

  group('CurrentNetworkRequests', () {
    late CurrentNetworkRequests currentNetworkRequests;
    late int notifyCount;
    void notifyCountIncrement() => notifyCount++;
    setUp(() {
      currentNetworkRequests = CurrentNetworkRequests();
      notifyCount = 0;
      currentNetworkRequests.addListener(notifyCountIncrement);
    });

    tearDown(() {
      currentNetworkRequests.removeListener(notifyCountIncrement);
    });

    group('http', () {
      final startTime = DateTime(2021).millisecondsSinceEpoch;
      final endTime = startTime + 1000;
      final httpBaseObject = {
        'id': '1',
        'isolateId': '2',
        'method': 'method1',
        'uri': 'http://test.com',
        'events': [],
        'startTime': startTime,
      };

      final socketStatObject = {
        'id': '20',
        'startTime': startTime,
        'lastReadTime': 25,
        'lastWriteTime': 30,
        'address': '0.0.0.0',
        'port': 1234,
        'socketType': 'ws',
        'readBytes': 20,
        'writeBytes': 40,
      };

      final request1Pending = HttpProfileRequest.parse(httpBaseObject)!;
      final request1Done = HttpProfileRequest.parse({
        ...httpBaseObject,
        'endTime': endTime,
      })!;
      final request2Pending = HttpProfileRequest.parse({
        ...httpBaseObject,
        'id': '2',
      })!;
      final request2Done = HttpProfileRequest.parse({
        ...httpBaseObject,
        'id': '2',
        'endTime': endTime,
      })!;

      final socketStats1Pending = SocketStatistic.parse({...socketStatObject})!;
      final socketStats1Done = SocketStatistic.parse({
        ...socketStatObject,
        ...{'endtime': endTime},
      })!;

      final socketStats2Pending =
          SocketStatistic.parse({...socketStatObject, 'id': '21'})!;

      test('adding multiple http requests notifies listeners only once', () {
        final reqs = [request1Pending, request2Pending];
        currentNetworkRequests.updateOrAddAll(
          requests: reqs,
          sockets: [],
          timelineMicrosOffset: 0,
        );
        expect(notifyCount, 1);

        expect(
          currentNetworkRequests.value.map((e) => e.id),
          reqs.map((e) => e.id),
        );

        currentNetworkRequests.updateOrAddAll(
          requests: [request1Done],
          sockets: [],
          timelineMicrosOffset: 0,
        );
        expect(notifyCount, 2);
        expect(
          currentNetworkRequests.value.map((e) => e.id),
          reqs.map((e) => e.id),
        );
      });

      test('adding multiple socket requests notifies listeners only once', () {
        final sockets = [
          socketStats1Pending,
          socketStats2Pending,
        ];
        currentNetworkRequests.updateOrAddAll(
          requests: [],
          sockets: sockets,
          timelineMicrosOffset: 0,
        );
        expect(notifyCount, 1);
        expect(
          currentNetworkRequests.value.map((e) => e.id),
          sockets.map((e) => e.id),
        );

        currentNetworkRequests.updateOrAddAll(
          requests: [],
          sockets: [socketStats1Done],
          timelineMicrosOffset: 0,
        );
        expect(notifyCount, 2);
        expect(
          currentNetworkRequests.value.map((e) => e.id),
          sockets.map((e) => e.id),
        );
      });

      test('adding socket and http requests notifies listeners only once', () {
        final reqs = [request1Pending, request2Pending];
        final sockets = [socketStats1Pending, socketStats2Pending];
        currentNetworkRequests.updateOrAddAll(
          requests: reqs,
          sockets: sockets,
          timelineMicrosOffset: 0,
        );
        expect(notifyCount, 1);
        expect(
          currentNetworkRequests.value.map((e) => e.id),
          [...reqs.map((e) => e.id), ...sockets.map((e) => e.id)],
        );

        currentNetworkRequests.updateOrAddAll(
          requests: [request1Done],
          sockets: [socketStats1Done],
          timelineMicrosOffset: 0,
        );
        expect(notifyCount, 2);
        expect(
          currentNetworkRequests.value.map((e) => e.id),
          [...reqs.map((e) => e.id), ...sockets.map((e) => e.id)],
        );
      });
    });
  });
}
