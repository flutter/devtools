// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app/src/screens/dtd/events.dart';
import 'package:devtools_app/src/screens/dtd/shared.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late EventsController controller;
  late MockDartToolingDaemon mockDtd;

  setUp(() {
    mockDtd = MockDartToolingDaemon();
    controller = EventsController()..dtd = mockDtd;
  });

  tearDown(() {
    controller.dispose();
  });

  group('$EventsController', () {
    test('init adds listeners for known DTD streams', () async {
      final streamListeners = <String, StreamController<DTDEvent>>{};
      for (final stream in knownDtdStreams) {
        final streamController = StreamController<DTDEvent>();
        streamListeners[stream] = streamController;
        when(
          mockDtd.onEvent(stream),
        ).thenAnswer((_) => streamController.stream);
      }

      controller.init();

      for (final stream in knownDtdStreams) {
        final event = DTDEvent(stream, 'test.event', {
          'message': 'Test event for $stream',
        }, DateTime.now().microsecondsSinceEpoch);
        streamListeners[stream]!.add(event);
        // Await a zero delay to give the event loop a chance to trigger the
        // listener added in `EventController.init`.
        await Future.delayed(Duration.zero);
        expect(controller.events.value, contains(event));
      }

      expect(controller.events.value.length, knownDtdStreams.length);

      for (final streamController in streamListeners.values) {
        await streamController.close();
      }
    });
  });

  group('$EventsView', () {
    setUp(() {
      setGlobal(IdeTheme, IdeTheme());
    });

    void addEvents() {
      final events = [
        DTDEvent(
          ConnectedAppServiceConstants.serviceName,
          ConnectedAppServiceConstants.vmServiceRegistered,
          {
            DtdParameters.uri: 'ws://127.0.0.1:30000/4G4UPw7fyoQ=/',
            DtdParameters.exposedUri: 'ws://127.0.0.1:30000/4G4UPw7fyoQ=/',
            DtdParameters.name: 'Flutter - Android (debug)',
          },
          0,
        ),
        DTDEvent(
          ConnectedAppServiceConstants.serviceName,
          ConnectedAppServiceConstants.vmServiceUnregistered,
          {
            DtdParameters.uri: 'ws://127.0.0.1:40000/4G4UPw7fyoQ=/',
            DtdParameters.exposedUri: 'ws://127.0.0.1:56050/4G4UPw7fyoQ=/',
            DtdParameters.name: 'Flutter - iOS (debug)',
          },
          1,
        ),
      ];
      controller.events
        ..clear()
        ..addAll(events);
    }

    testWidgets('displays no events initially', (tester) async {
      await tester.pumpWidget(wrapSimple(EventsView(controller: controller)));
      expect(find.text('No events received'), findsOneWidget);
    });

    testWidgets('displays events after they are added', (tester) async {
      addEvents();

      await tester.pumpWidget(wrapSimple(EventsView(controller: controller)));

      expect(find.byType(ListTile), findsNWidgets(2));
      expect(
        find.text('[${ConnectedAppServiceConstants.serviceName}]'),
        findsNWidgets(2),
      );
      expect(
        find.text(ConnectedAppServiceConstants.vmServiceRegistered),
        findsOneWidget,
      );
      expect(
        find.text(ConnectedAppServiceConstants.vmServiceUnregistered),
        findsOneWidget,
      );
    });

    testWidgetsWithWindowSize('can select events', const Size(2000.0, 2000.0), (
      tester,
    ) async {
      addEvents();

      await tester.pumpWidget(wrapSimple(EventsView(controller: controller)));
      expect(
        _findInDetailsView(find.text('No event selected')),
        findsOneWidget,
      );

      final firstEventFinder = find.byType(ListTile).first;
      await tester.tap(firstEventFinder);
      await tester.pumpAndSettle();

      expect(controller.selectedEvent.value, controller.events.value.first);
      expect(_findInDetailsView(find.text('No event selected')), findsNothing);
      expect(_findInDetailsView(find.text('Event details')), findsOneWidget);

      expect(_findInDetailsView(find.text('Stream:')), findsOneWidget);
      expect(
        _findInDetailsView(find.text(ConnectedAppServiceConstants.serviceName)),
        findsOneWidget,
      );

      expect(_findInDetailsView(find.text('Kind:')), findsOneWidget);
      expect(
        _findInDetailsView(
          find.text(ConnectedAppServiceConstants.vmServiceRegistered),
        ),
        findsOneWidget,
      );

      expect(_findInDetailsView(find.text('Timestamp:')), findsOneWidget);
      expect(_findInDetailsView(find.text('0')), findsOneWidget);

      expect(_findInDetailsView(find.text('Data:')), findsOneWidget);
      expect(
        _findInDetailsView(
          find.text(
            '{uri: ws://127.0.0.1:30000/4G4UPw7fyoQ=/, exposedUri: ws://127.0.0.1:30000/4G4UPw7fyoQ=/, name: Flutter - Android (debug)}',
          ),
        ),
        findsOneWidget,
      );

      // Select another event and verify the event details view is updated.
      final lastEventFinder = find.byType(ListTile).last;
      await tester.tap(lastEventFinder);
      await tester.pumpAndSettle();

      expect(controller.selectedEvent.value, controller.events.value.last);
      expect(_findInDetailsView(find.text('Event details')), findsOneWidget);

      expect(_findInDetailsView(find.text('Stream:')), findsOneWidget);
      expect(
        _findInDetailsView(find.text(ConnectedAppServiceConstants.serviceName)),
        findsOneWidget,
      );

      expect(_findInDetailsView(find.text('Kind:')), findsOneWidget);
      expect(
        _findInDetailsView(
          find.text(ConnectedAppServiceConstants.vmServiceUnregistered),
        ),
        findsOneWidget,
      );

      expect(_findInDetailsView(find.text('Timestamp:')), findsOneWidget);
      expect(_findInDetailsView(find.text('1')), findsOneWidget);

      expect(_findInDetailsView(find.text('Data:')), findsOneWidget);
      expect(
        _findInDetailsView(
          find.text(
            '{uri: ws://127.0.0.1:40000/4G4UPw7fyoQ=/, exposedUri: ws://127.0.0.1:56050/4G4UPw7fyoQ=/, name: Flutter - iOS (debug)}',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('EventsView clears events and selected event', (tester) async {
      addEvents();
      await tester.pumpWidget(wrapSimple(EventsView(controller: controller)));
      expect(find.text('No events received'), findsNothing);
      expect(find.byType(ListTile), findsNWidgets(2));

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(controller.events.value, isEmpty);
      expect(controller.selectedEvent.value, isNull);
      expect(find.byType(ListTile), findsNothing);
      expect(find.text('No events received'), findsOneWidget);
    });
  });
}

Finder _findInDetailsView(Finder finder) {
  return find.descendant(of: find.byType(EventDetailView), matching: finder);
}
