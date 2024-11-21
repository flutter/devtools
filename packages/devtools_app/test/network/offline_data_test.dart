// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/src/screens/network/network_model.dart';
import 'package:devtools_app/src/screens/network/offline_network_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, Object?> jsonData;
  late OfflineNetworkData offlineData;
  late Socket firstSocket;
  late Socket secondSocket;

  setUpAll(() {
    final file = File('test/network/sample_network_offline_data.json');
    final fileContent = file.readAsStringSync();
    jsonData = jsonDecode(fileContent) as Map<String, Object?>;

    // Create OfflineNetworkData
    offlineData = OfflineNetworkData.fromJson(jsonData);

    // Extracting sockets for reuse in tests
    firstSocket = offlineData.socketData.first;
    secondSocket = offlineData.socketData.last;
  });

  group('Socket Tests', () {
    test('Socket should deserialize from JSON correctly', () {
      // Validate first socket
      expect(firstSocket.id, '105553123901536');
      expect(firstSocket.socketType, 'tcp');
      expect(firstSocket.port, 443);
      expect(firstSocket.readBytes, 4367);
      expect(firstSocket.writeBytes, 18237);

      // Validate timestamps
      const timelineMicrosBase = 1731482170837171;
      expect(
        firstSocket.startTimestamp,
        DateTime.fromMicrosecondsSinceEpoch(timelineMicrosBase + 171830570040),
      );
      expect(
        firstSocket.endTimestamp,
        DateTime.fromMicrosecondsSinceEpoch(timelineMicrosBase + 171830929647),
      );
      expect(
        firstSocket.lastReadTimestamp,
        DateTime.fromMicrosecondsSinceEpoch(timelineMicrosBase + 171830928421),
      );
      expect(
        firstSocket.lastWriteTimestamp,
        DateTime.fromMicrosecondsSinceEpoch(timelineMicrosBase + 171830669180),
      );
    });

    test('Socket should serialize to JSON correctly', () {
      final serializedJson = firstSocket.toJson();

      // Validate serialized JSON
      expect(serializedJson['timelineMicrosBase'], 1731482170837171);
      expect((serializedJson['socket'] as Map)['id'], '105553123901536');
      expect((serializedJson['socket'] as Map)['startTime'], 171830570040);
      expect((serializedJson['socket'] as Map)['endTime'], 171830929647);
      expect((serializedJson['socket'] as Map)['readBytes'], 4367);
      expect((serializedJson['socket'] as Map)['writeBytes'], 18237);
    });

    test('Socket duration should be calculated correctly', () {
      final expectedDuration = Duration(
        microseconds: firstSocket.endTimestamp!.microsecondsSinceEpoch -
            firstSocket.startTimestamp.microsecondsSinceEpoch,
      );

      expect(firstSocket.duration, expectedDuration);
    });

    test('Socket status should indicate "Open" or "Closed" based on endTime',
        () {
      expect(
        firstSocket.status,
        'Closed',
      ); // The provided socket has an endTime

      // Modify socket to simulate "Open" status
      final openSocketJson = {
        ...firstSocket.toJson(),
        'socket': {
          ...(firstSocket.toJson()['socket'] as Map<String, Object?>),
          'endTime': null,
        },
      };
      final openSocket = Socket.fromJson(openSocketJson);

      expect(openSocket.status, 'Open'); // No endTime indicates "Open"
    });

    test('Socket equality and hash code should work correctly', () {
      expect(firstSocket == secondSocket, isFalse);
      expect(firstSocket.hashCode != secondSocket.hashCode, isTrue);

      final duplicateSocket = Socket.fromJson(firstSocket.toJson());
      expect(firstSocket, equals(duplicateSocket));
      expect(firstSocket.hashCode, equals(duplicateSocket.hashCode));
    });
  });

  group('OfflineNetworkData Tests', () {
    test('OfflineNetworkData should deserialize correctly', () {
      // Validate httpRequestData
      expect(offlineData.httpRequestData.length, 2);
      expect(offlineData.httpRequestData.first.id, '975585676925010898');
      expect(offlineData.httpRequestData.first.method, 'GET');
      expect(
        offlineData.httpRequestData.first.uri,
        'https://jsonplaceholder.typicode.com/albums/1',
      );

      // Validate socketData
      expect(offlineData.socketData.length, 2);

      // Validate selectedRequestId
      expect(offlineData.selectedRequestId, isNull);
    });

    test('OfflineNetworkData should serialize correctly', () {
      final serializedJson = offlineData.toJson();

      // Validate serialized JSON
      final httpRequestData = serializedJson['httpRequestData'] as List;
      final firstRequest = httpRequestData.first as Map<String, Object?>;
      final requestDetails = firstRequest['request'] as Map<String, Object?>;

      expect(requestDetails['id'], '975585676925010898');
    });

    test(
        'isEmpty should return true when both httpRequestData and socketData are empty',
        () {
      final emptyOfflineData = OfflineNetworkData(
        httpRequestData: [],
        socketData: [],
      );

      expect(emptyOfflineData.isEmpty, isTrue);
    });

    test('isEmpty should return false when httpRequestData is populated', () {
      final populatedHttpData = OfflineNetworkData(
        httpRequestData: offlineData.httpRequestData,
        socketData: [],
      );

      expect(populatedHttpData.isEmpty, isFalse);
    });

    test('toJson and fromJson should preserve data integrity', () {
      final serializedJson = offlineData.toJson();
      final restoredData = OfflineNetworkData.fromJson(serializedJson);

      expect(
        restoredData.httpRequestData.length,
        offlineData.httpRequestData.length,
      );
      expect(restoredData.socketData.length, offlineData.socketData.length);
      expect(restoredData.selectedRequestId, offlineData.selectedRequestId);
    });
  });
}
