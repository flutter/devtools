// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('vm')
library;

import 'package:devtools_app/devtools_app.dart';
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
      setGlobal(OfflineDataController, OfflineDataController());
      setGlobal(ScreenControllers, ScreenControllers());
      socketProfile = loadSocketProfile();
      httpProfile = loadHttpProfile();
      fakeServiceConnection = FakeServiceConnectionManager(
        service: FakeServiceManager.createFakeService(
          socketProfile: socketProfile,
          httpProfile: httpProfile,
        ),
      );
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      setGlobal(PreferencesController, PreferencesController());
      screenControllers.register<NetworkController>(() => NetworkController());
      // Lookup the controller immediately to force initialization.
      controller = screenControllers.lookup<NetworkController>();
    });

    tearDown(() {
      screenControllers.disposeConnectedControllers();
    });

    test('initialize recording state', () async {
      expect(controller.isPolling, false);

      // Fake service pretends HTTP timeline logging and socket profiling are
      // always enabled.
      await controller.startRecording();
      expect(controller.isPolling, true);
      await controller.stopRecording();
    });

    test('start and pause recording', () async {
      expect(controller.isPolling, false);
      await addListenerScope(
        listenable: controller.recordingNotifier,
        listener: () {
          expect(controller.recordingNotifier.value, true);
          expect(controller.isPolling, true);
        },
        callback: () async {
          await controller.startRecording();
        },
      );

      // Pause polling.
      await controller.togglePolling(false);
      expect(controller.recordingNotifier.value, false);
      expect(controller.isPolling, false);

      // Resume polling.
      await controller.togglePolling(true);
      expect(controller.recordingNotifier.value, true);
      expect(controller.isPolling, true);

      await controller.stopRecording();
      expect(controller.recordingNotifier.value, false);
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
      final httpRequests = requests.whereType<DartIOHttpRequestData>().toList();
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
      await controller.stopRecording();
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
      expect(
        controller.matchesForSearch('2606:4700:3037::ac43').length,
        equals(2),
      );
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

      controller.search = '2606:4700:3037::ac43';
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
      expect(controller.filteredData.value, hasLength(4));

      controller.setActiveFilter(query: 'method:socket');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(2));

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
      expect(controller.filteredData.value, hasLength(1));

      controller.setActiveFilter(query: '-s:Error');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(8));

      controller.setActiveFilter(query: 'type:json');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(4));

      controller.setActiveFilter(query: 't:tcp');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(2));

      controller.setActiveFilter(query: '-t:tcp');
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

      controller.setActiveFilter(query: '-t:tcp,http');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(4));

      controller.setActiveFilter(query: '-t:tcp,http method:put');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(1));

      controller.setActiveFilter(query: '-status:error method:get');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(3));

      controller.setActiveFilter(query: '-status:error method:get t:http');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(2));
    });

    group('filterHttpSockets', () {
      // The test socket profile contains 2 sockets with socketType 'tcp'.
      // These are the sockets created by the HTTP profiler that should be
      // hidden when filterHttpSockets is enabled.
      const numRequests = 9;
      const numTcpSockets = 2;
      const numRequestsWithoutTcpSockets = numRequests - numTcpSockets;

      setUp(() async {
        await controller.startRecording();
        await controller.networkService.refreshNetworkData();
        // Ensure all requests are loaded and no filter is active.
        expect(controller.requests.value, hasLength(numRequests));
        expect(controller.filteredData.value, hasLength(numRequests));
      });

      tearDown(() async {
        // Always reset the toggle so it doesn't bleed into other tests.
        controller.filterHttpSockets.value = false;
        await controller.stopRecording();
      });

      test('defaults to false (all sockets visible)', () {
        expect(controller.filterHttpSockets.value, false);
        expect(controller.filteredData.value, hasLength(numRequests));

        // Confirm the 2 tcp sockets are present when filter is off.
        final tcpSockets = controller.filteredData.value
            .whereType<Socket>()
            .where((s) => s.socketType == 'tcp')
            .toList();
        expect(tcpSockets, hasLength(numTcpSockets));
      });

      test('enabling hides tcp sockets from filteredData', () {
        controller.filterHttpSockets.value = true;

        expect(
          controller.filteredData.value,
          hasLength(numRequestsWithoutTcpSockets),
        );

        // No tcp sockets should remain in the filtered list.
        final tcpSockets = controller.filteredData.value
            .whereType<Socket>()
            .where((s) => s.socketType == 'tcp')
            .toList();
        expect(tcpSockets, isEmpty);
      });

      test('enabling does not hide websocket sockets', () {
        // Inject a websocket socket via the public processNetworkTraffic API
        // to verify it is preserved when the filter is active.
        controller.processNetworkTraffic(
          sockets: [
            SocketStatistic.parse({
              'id': 'ws-1',
              'startTime': DateTime(2021).microsecondsSinceEpoch,
              'lastReadTime': 25,
              'lastWriteTime': 30,
              'address': '1.2.3.4',
              'port': 443,
              'socketType': 'websocket',
              'readBytes': 10,
              'writeBytes': 10,
            })!,
          ],
          httpRequests: [],
        );

        // Now enable the filter — tcp sockets should be hidden, websocket kept.
        controller.filterHttpSockets.value = true;

        final webSockets = controller.filteredData.value
            .whereType<Socket>()
            .where((s) => s.socketType == 'websocket')
            .toList();
        expect(webSockets, hasLength(1));

        final tcpSockets = controller.filteredData.value
            .whereType<Socket>()
            .where((s) => s.socketType == 'tcp')
            .toList();
        expect(tcpSockets, isEmpty);
      });

      test('disabling restores tcp sockets in filteredData', () {
        // Enable and verify sockets are hidden.
        controller.filterHttpSockets.value = true;
        expect(
          controller.filteredData.value,
          hasLength(numRequestsWithoutTcpSockets),
        );

        // Disable and verify sockets are restored.
        controller.filterHttpSockets.value = false;
        expect(controller.filteredData.value, hasLength(numRequests));

        final tcpSockets = controller.filteredData.value
            .whereType<Socket>()
            .where((s) => s.socketType == 'tcp')
            .toList();
        expect(tcpSockets, hasLength(numTcpSockets));
      });

      test('raw requests list is never modified by the toggle', () {
        // Enabling the filter must never mutate the underlying requests list —
        // only filteredData should change.
        controller.filterHttpSockets.value = true;
        expect(controller.requests.value, hasLength(numRequests));

        controller.filterHttpSockets.value = false;
        expect(controller.requests.value, hasLength(numRequests));
      });

      test('composes correctly with query filter', () {
        // With socket filter on AND a query filter that matches HTTP requests
        // only, tcp sockets should be excluded by the socket filter before
        // the query filter runs.
        controller.filterHttpSockets.value = true;
        controller.setActiveFilter(query: 'jsonplaceholder');

        // 5 HTTP requests match 'jsonplaceholder'; 0 tcp sockets should appear.
        expect(controller.filteredData.value, hasLength(5));
        final tcpSockets = controller.filteredData.value
            .whereType<Socket>()
            .where((s) => s.socketType == 'tcp')
            .toList();
        expect(tcpSockets, isEmpty);

        // Reset query filter but keep socket filter on.
        controller.setActiveFilter();
        expect(
          controller.filteredData.value,
          hasLength(numRequestsWithoutTcpSockets),
        );
      });
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
      final startTime = DateTime(2021).microsecondsSinceEpoch;
      final endTime = startTime + 1000000;
      final httpBaseObject = {
        'id': '101',
        'isolateId': '2',
        'method': 'method1',
        'uri': 'http://test.com',
        'events': [],
        'startTime': startTime,
      };

      final socketStatObject = {
        'id': '21',
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
        'response': {
          'startTime': startTime,
          'endTime': endTime,
          'redirects': [],
          'statusCode': 200,
        },
      })!;
      final request2Pending = HttpProfileRequest.parse({
        ...httpBaseObject,
        'id': '102',
      })!;

      final socketStats1Pending = SocketStatistic.parse({...socketStatObject})!;
      final socketStats1Done = SocketStatistic.parse({
        ...socketStatObject,
        'endTime': endTime,
      })!;

      final socketStats2Pending = SocketStatistic.parse({
        ...socketStatObject,
        'id': '22',
      })!;

      test(
        'adding multiple socket and http requests notifies listeners only once',
        () {
          final reqs = [request1Pending, request2Pending];
          final sockets = [socketStats1Pending, socketStats2Pending];
          currentNetworkRequests.updateOrAddAll(
            requests: reqs,
            sockets: sockets,
            timelineMicrosOffset: 0,
          );
          expect(notifyCount, 1);

          // Check that all requests ids are present and that there are no
          // endtimes
          expect(
            currentNetworkRequests.value.map((e) => [e.id, e.endTimestamp]),
            [
              ['101', null],
              ['102', null],
              ['21', null],
              ['22', null],
            ],
          );

          currentNetworkRequests.updateOrAddAll(
            requests: [request1Done],
            sockets: [socketStats1Done],
            timelineMicrosOffset: 0,
          );
          expect(notifyCount, 2);
          // Check that all requests ids are present and that the endtimes have
          // been updated accordingly
          expect(
            currentNetworkRequests.value.map(
              (e) => [e.id, e.endTimestamp?.microsecondsSinceEpoch],
            ),
            [
              ['101', endTime],
              ['102', null],
              ['21', endTime],
              ['22', null],
            ],
          );
        },
      );

      test('clear', () {
        final reqs = [request1Pending, request2Pending];
        final sockets = [socketStats1Pending, socketStats2Pending];
        currentNetworkRequests.updateOrAddAll(
          requests: reqs,
          sockets: sockets,
          timelineMicrosOffset: 0,
        );

        // Check that all requests ids are present and that there are no
        // endtimes
        expect(
          currentNetworkRequests.value.map((e) => [e.id, e.endTimestamp]),
          [
            ['101', null],
            ['102', null],
            ['21', null],
            ['22', null],
          ],
        );

        currentNetworkRequests.clear();
        expect(currentNetworkRequests.value, isEmpty);
      });

      test('partial clear', () {
        final reqs = [request1Pending, request2Pending];
        final sockets = [socketStats1Pending, socketStats2Pending];
        currentNetworkRequests.updateOrAddAll(
          requests: reqs,
          sockets: sockets,
          timelineMicrosOffset: 0,
        );

        // Check that all requests ids are present and that there are no
        // endtimes
        expect(
          currentNetworkRequests.value.map((e) => [e.id, e.endTimestamp]),
          [
            ['101', null],
            ['102', null],
            ['21', null],
            ['22', null],
          ],
        );

        currentNetworkRequests.clear(partial: true);
        expect(currentNetworkRequests.value.length, 2);
        expect(
          currentNetworkRequests.value.map((e) => [e.id, e.endTimestamp]),
          [
            ['21', null],
            ['22', null],
          ],
        );
      });
    });
  });
}