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
        expect(
          request.duration,
          request.inProgress || request.endTimestamp == null
              ? isNull
              : isNotNull,
        );
        expect(request.general.length, greaterThan(0));
        expect(httpMethods.contains(request.method), true);
        if (request.inProgress) {
          expect(request.status, isNull);
        }
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
      final errorCount = profile
          .whereType<DartIOHttpRequestData>()
          .where((request) => request.status == 'Error')
          .length;
      expect(controller.filteredData.value, hasLength(errorCount));

      final firstStatus = profile
          .whereType<DartIOHttpRequestData>()
          .map((request) => request.status)
          .whereType<String>()
          .first;
      final firstStatusCount = profile
          .whereType<DartIOHttpRequestData>()
          .where((request) => request.status == firstStatus)
          .length;
      controller.setActiveFilter(query: 's:$firstStatus');
      expect(profile, hasLength(numRequests));
      expect(controller.filteredData.value, hasLength(firstStatusCount));

      controller.setActiveFilter(query: '-s:Error');
      expect(profile, hasLength(numRequests));
      expect(
        controller.filteredData.value,
        hasLength(numRequests - errorCount),
      );

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
      final nonErrorGetCount = profile
          .whereType<DartIOHttpRequestData>()
          .where(
            (request) =>
                request.method.toLowerCase() == 'get' &&
                request.status?.toLowerCase() != 'error',
          )
          .length;
      expect(controller.filteredData.value, hasLength(nonErrorGetCount));

      controller.setActiveFilter(query: '-status:error method:get t:http');
      expect(profile, hasLength(numRequests));
      final nonErrorGetHttpCount = profile
          .whereType<DartIOHttpRequestData>()
          .where(
            (request) =>
                request.method.toLowerCase() == 'get' &&
                request.status?.toLowerCase() != 'error' &&
                request.type.toLowerCase() == 'http',
          )
          .length;
      expect(controller.filteredData.value, hasLength(nonErrorGetHttpCount));
    });

    test('filterData hides tcp sockets via setting filter', () async {
      await controller.startRecording();
      await controller.networkService.refreshNetworkData();

      const numRequests = 9;
      const numTcpSockets = 2;

      expect(controller.filteredData.value, hasLength(numRequests));

      // Enable the hide HTTP sockets toggle filter using activeFilter.
      final socketFilter = controller.activeFilter.value.settingFilters[0];
      socketFilter.setting.value = true;
      controller.setActiveFilter();

      expect(
        controller.filteredData.value,
        hasLength(numRequests - numTcpSockets),
      );

      final tcpSockets = controller.filteredData.value
          .whereType<Socket>()
          .where((s) => s.socketType == 'tcp')
          .toList();
      expect(tcpSockets, isEmpty);

      // Disable and verify sockets are restored.
      socketFilter.setting.value = false;
      controller.setActiveFilter();
      expect(controller.filteredData.value, hasLength(numRequests));
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
      final request1CancelledWithStatusCode = HttpProfileRequest.parse({
        ...httpBaseObject,
        'events': [
          {
            'timestamp': startTime + 100,
            'event': 'Request cancelled by client',
          },
        ],
        'response': {
          'startTime': startTime,
          'endTime': null,
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
            webSockets: const [],
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
            webSockets: const [],
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

      test('latest request update wins over stale status for same id', () {
        currentNetworkRequests.updateOrAddAll(
          requests: [request1Done],
          sockets: const [],
          webSockets: const [],
          timelineMicrosOffset: 0,
        );

        final initialRequest =
            currentNetworkRequests.getRequest('101')! as DartIOHttpRequestData;
        expect(initialRequest.status, '200');
        expect(initialRequest.status, isNot('Cancelled'));

        currentNetworkRequests.updateOrAddAll(
          requests: [request1CancelledWithStatusCode],
          sockets: const [],
          webSockets: const [],
          timelineMicrosOffset: 0,
        );

        final updatedRequest =
            currentNetworkRequests.getRequest('101')! as DartIOHttpRequestData;
        expect(updatedRequest.status, 'Cancelled');
        expect(updatedRequest.inProgress, false);
      });

      test('clear', () {
        final reqs = [request1Pending, request2Pending];
        final sockets = [socketStats1Pending, socketStats2Pending];
        currentNetworkRequests.updateOrAddAll(
          requests: reqs,
          sockets: sockets,
          webSockets: const [],
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
          webSockets: const [],
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
    group('websocket', () {
      final connectTime = DateTime(2026, 8, 18, 10).toUtc();
      final openTime = connectTime.add(const Duration(seconds: 1));
      final lastUpdated = openTime.add(const Duration(seconds: 2));

      final events = [
        WebSocketEvent(event: 'WebSocket.Connect', timestamp: connectTime),
        WebSocketEvent(
          event: 'WebSocket.Send',
          timestamp: openTime,
          frameNumber: 1,
          direction: 'out',
          opcode: 'text',
          payloadSize: 5,
        ),
        WebSocketEvent(
          event: 'WebSocket.Receive',
          timestamp: lastUpdated,
          frameNumber: 2,
          direction: 'in',
          opcode: 'text',
          payloadSize: 7,
        ),
      ];

      WebSocketConnection createConnection({
        String id = '42',
        String state = 'open',
        int bytesSent = 5,
        int bytesReceived = 7,
        int framesSent = 1,
        int framesReceived = 1,
        List<WebSocketEvent>? connectionEvents,
      }) {
        return WebSocketConnection(
          isolateId: 'isolate-1',
          id: id,
          uri: Uri.parse('wss://example.com/socket'),
          state: state,
          protocol: 'chat',
          connectTimestamp: connectTime,
          openTimestamp: openTime,
          bytesSent: bytesSent,
          bytesReceived: bytesReceived,
          framesSent: framesSent,
          framesReceived: framesReceived,
          pingCount: 2,
          pongCount: 2,
          lastUpdated: lastUpdated,
          events: connectionEvents ?? events,
        );
      }

      test('adds WebSocket connection', () {
        final connection = createConnection();

        currentNetworkRequests.updateOrAddAll(
          requests: const [],
          sockets: const [],
          webSockets: [connection],
          timelineMicrosOffset: 0,
        );

        expect(currentNetworkRequests.value, hasLength(1));

        final request = currentNetworkRequests.getRequest(
          'websocket:isolate-1:42',
        );

        expect(request, isA<WebSocket>());

        final webSocket = request! as WebSocket;
        expect(webSocket.connectionId, '42');
        expect(webSocket.uri, 'wss://example.com/socket');
        expect(webSocket.protocol, 'chat');
        expect(webSocket.state, 'open');
        expect(webSocket.bytesSent, 5);
        expect(webSocket.bytesReceived, 7);
        expect(webSocket.framesSent, 1);
        expect(webSocket.framesReceived, 1);
        expect(webSocket.pingCount, 2);
        expect(webSocket.pongCount, 2);
        expect(webSocket.events, hasLength(3));
      });

      test('updates existing WebSocket instead of adding duplicate', () {
        final initialConnection = createConnection();

        currentNetworkRequests.updateOrAddAll(
          requests: const [],
          sockets: const [],
          webSockets: [initialConnection],
          timelineMicrosOffset: 0,
        );

        final updatedConnection = createConnection(
          bytesSent: 15,
          bytesReceived: 27,
          framesSent: 3,
          framesReceived: 4,
          connectionEvents: [
            ...events,
            WebSocketEvent(
              event: 'WebSocket.Send',
              timestamp: lastUpdated,
              frameNumber: 3,
              direction: 'out',
              opcode: 'binary',
              payloadSize: 10,
            ),
          ],
        );

        currentNetworkRequests.updateOrAddAll(
          requests: const [],
          sockets: const [],
          webSockets: [updatedConnection],
          timelineMicrosOffset: 0,
        );

        expect(currentNetworkRequests.value, hasLength(1));

        final request = currentNetworkRequests.getRequest(
          'websocket:isolate-1:42',
        );

        expect(request, isA<WebSocket>());

        final webSocket = request! as WebSocket;
        expect(webSocket.bytesSent, 15);
        expect(webSocket.bytesReceived, 27);
        expect(webSocket.framesSent, 3);
        expect(webSocket.framesReceived, 4);
        expect(webSocket.events, hasLength(4));
      });

      test('notifies listeners once for multiple WebSocket connections', () {
        final connection1 = createConnection();

        final connection2 = createConnection(id: '43');

        currentNetworkRequests.updateOrAddAll(
          requests: const [],
          sockets: const [],
          webSockets: [connection1, connection2],
          timelineMicrosOffset: 0,
        );

        expect(currentNetworkRequests.value, hasLength(2));
        expect(notifyCount, 1);
      });

      test('maps closed WebSocket state and duration', () {
        final closeTime = openTime.add(const Duration(seconds: 5));

        final connection = WebSocketConnection(
          isolateId: 'isolate-1',
          id: '44',
          uri: Uri.parse('wss://example.com/socket'),
          state: 'closed',
          protocol: 'chat',
          connectTimestamp: connectTime,
          openTimestamp: openTime,
          closeTimestamp: closeTime,
          closeCode: 1000,
          closeReason: 'Normal closure',
          lastUpdated: closeTime,
          events: const [],
        );

        final webSocket = WebSocket(connection);

        expect(webSocket.state, 'closed');
        expect(webSocket.inProgress, false);
        expect(webSocket.didFail, false);
        expect(webSocket.endTimestamp, closeTime);
        expect(webSocket.duration, closeTime.difference(connectTime));
        expect(webSocket.closeCode, 1000);
        expect(webSocket.closeReason, 'Normal closure');
      });

      test('maps WebSocket error state', () {
        final connection = WebSocketConnection(
          isolateId: 'isolate-1',
          id: '45',
          uri: Uri.parse('wss://example.com/socket'),
          state: 'error',
          connectTimestamp: connectTime,
          closeTimestamp: lastUpdated,
          error: 'Connection failed',
          lastUpdated: lastUpdated,
          events: const [],
        );

        final webSocket = WebSocket(connection);

        expect(webSocket.state, 'error');
        expect(webSocket.didFail, true);
        expect(webSocket.inProgress, false);
        expect(webSocket.error, 'Connection failed');
      });
    });
  });
}
