// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:async/async.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  final fakeDtdUri = Uri.parse('ws://127.0.0.1:65314/KKXNgPdXnFk=');

  group('serviceRegistrationBroadcastStream', () {
    final fooBarRegisteredEvent = DTDEvent('Service', 'ServiceRegistered', {
      'service': 'foo',
      'method': 'bar',
    }, 1);
    final bazQuxRegisteredEvent = DTDEvent('Service', 'ServiceRegistered', {
      'service': 'baz',
      'method': 'qux',
    }, 2);
    final fooBarUnregisteredEvent = DTDEvent('Service', 'ServiceUnregistered', {
      'service': 'foo',
      'method': 'bar',
    }, 4);
    final invalidEvent = DTDEvent('Service', 'Invalid', {}, 3);

    late TestDTDManager manager;
    late MockDartToolingDaemon mockDtd1;
    late MockDartToolingDaemon mockDtd2;

    /// Sets up the [mockDTD] to return a [StreamController] so that events can
    /// be added to the stream during the test.
    StreamController<DTDEvent> setUpEventStream(MockDartToolingDaemon mockDTD) {
      final streamController = StreamController<DTDEvent>();
      when(mockDTD.streamListen(any)).thenAnswer((_) async => const Success());
      when(mockDTD.onEvent(any)).thenAnswer((_) => streamController.stream);
      return streamController;
    }

    setUp(() {
      mockDtd1 = MockDartToolingDaemon();
      mockDtd2 = MockDartToolingDaemon();
      manager = TestDTDManager();
    });

    tearDown(() async {
      await manager.dispose();
    });

    test('supports multiple subscribers', () async {
      // Connect to DTD.
      final streamController = setUpEventStream(mockDtd1);
      manager.mockDtd = mockDtd1;
      await manager.connect(fakeDtdUri);

      // Create two subscribers.
      final eventQueue1 = StreamQueue(
        manager.serviceRegistrationBroadcastStream,
      );
      final eventQueue2 = StreamQueue(
        manager.serviceRegistrationBroadcastStream,
      );

      try {
        // Add an event.
        streamController.add(fooBarRegisteredEvent);

        // Verify both subscribers received the event.
        expect(await eventQueue1.next, equals(fooBarRegisteredEvent));
        expect(await eventQueue2.next, equals(fooBarRegisteredEvent));
      } finally {
        await eventQueue1.cancel();
        await eventQueue2.cancel();
      }
    });

    test(
      'only forwards ServiceRegistered and ServiceUnregistered events',
      () async {
        // Connect to DTD.
        final streamController = setUpEventStream(mockDtd1);
        manager.mockDtd = mockDtd1;
        await manager.connect(fakeDtdUri);

        // Subscribe to the service registration stream.
        final eventQueue = StreamQueue(
          manager.serviceRegistrationBroadcastStream,
        );

        try {
          // The manager only forwards registered and unregistered events.
          streamController.add(fooBarRegisteredEvent);
          streamController.add(invalidEvent);
          streamController.add(fooBarUnregisteredEvent);
          expect(
            manager.serviceRegistrationBroadcastStream,
            emitsInOrder([fooBarRegisteredEvent, fooBarUnregisteredEvent]),
          );
        } finally {
          await eventQueue.cancel();
        }
      },
    );

    test('forwards events across multiple DTD connections', () async {
      // Connect to the first DTD instance.
      final streamController1 = setUpEventStream(mockDtd1);
      manager.mockDtd = mockDtd1;
      await manager.connect(fakeDtdUri);

      final eventQueue = StreamQueue(
        manager.serviceRegistrationBroadcastStream,
      );

      try {
        // The manager forwards events from the first DTD instance.
        streamController1.add(fooBarRegisteredEvent);
        expect(await eventQueue.next, equals(fooBarRegisteredEvent));

        // Connect to the second DTD instance:
        final streamController2 = setUpEventStream(mockDtd2);
        manager.mockDtd = mockDtd2;
        await manager.connect(fakeDtdUri);

        // The manager forwards events from the second DTD instance.
        streamController2.add(bazQuxRegisteredEvent);
        expect(await eventQueue.next, equals(bazQuxRegisteredEvent));
      } finally {
        await eventQueue.cancel();
      }
    });

    test('continues to forward events while DTD is reconnecting', () async {
      // Connect to DTD.
      final streamController = setUpEventStream(mockDtd1);
      final dtdDoneCompleter = Completer<void>();
      when(mockDtd1.done).thenAnswer((_) => dtdDoneCompleter.future);
      manager.mockDtd = mockDtd1;
      await manager.connect(fakeDtdUri);

      // Subscribe to the service registration stream.
      final eventQueue = StreamQueue(
        manager.serviceRegistrationBroadcastStream,
      );
      try {
        // Send events while DTD is reconnecting.
        manager.connectionState.addListener(() {
          if (manager.connectionState.value is NotConnectedDTDState) {
            streamController.add(fooBarRegisteredEvent);
          }
          if (manager.connectionState.value is ConnectingDTDState) {
            streamController.add(bazQuxRegisteredEvent);
          }
        });

        // Trigger a done event to force DTD to reconnect.
        dtdDoneCompleter.complete();

        // Verify the events sent during reconnection were received.
        expect(await eventQueue.next, equals(fooBarRegisteredEvent));
        expect(await eventQueue.next, equals(bazQuxRegisteredEvent));
      } finally {
        await eventQueue.cancel();
      }
    });
  });
}

class TestDTDManager extends DTDManager {
  DartToolingDaemon? mockDtd;

  @override
  Future<DartToolingDaemon> connectDtdImpl(Uri uri) async {
    return mockDtd!;
  }
}
