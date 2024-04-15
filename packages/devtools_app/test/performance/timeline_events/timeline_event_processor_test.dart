// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/performance/panes/timeline_events/timeline_event_processor.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service_protos/vm_service_protos.dart';

import '../../test_infra/test_data/performance/sample_performance_data.dart';

void main() {
  final originalTrackEventPackets = List.of(allTrackEventPackets);
  final originalTrackDescriptorEvents = List.of(trackDescriptorEvents);

  late TestTimelineEventsController timelineEventsController;

  setUp(() {
    // If any of these expect statements fail, a golden was modified while the
    // tests were running. Do not modify the original lists. Instead, make a
    // copy and modify the copy.
    expect(
      collectionEquals(allTrackEventPackets, originalTrackEventPackets),
      isTrue,
    );
    expect(
      collectionEquals(trackDescriptorEvents, originalTrackDescriptorEvents),
      isTrue,
    );

    setGlobal(IdeTheme, IdeTheme());
    setGlobal(OfflineDataController, OfflineDataController());
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
  });

  group('$FlutterTimelineEventProcessor', () {
    late FlutterTimelineEventProcessor processor;
    late List<PerfettoTrackEvent> trackEvents;

    setUp(() {
      final mockPerformanceController =
          createMockPerformanceControllerWithDefaults();
      timelineEventsController =
          TestTimelineEventsController(mockPerformanceController);
      when(mockPerformanceController.timelineEventsController)
          .thenReturn(timelineEventsController);
      processor = timelineEventsController.perfettoController.processor
        ..primeTrackIds(
          ui: testUiTrackId,
          raster: testRasterTrackId,
        );

      trackEvents = allTrackEventPackets
          .map(
            (packetJson) => PerfettoTrackEvent.fromPacket(
              TracePacket.fromJson(jsonEncode(packetJson)),
            ),
          )
          .toList();
    });

    test('slice events form timeline event tree', () {
      processor.processTrackEvents(trackEvents);
      expect(timelineEventsController.events.length, 6);
    });

    test('sets timeline event type', () {
      processor.processTrackEvents(trackEvents);
      for (final event in timelineEventsController.events) {
        expect(event.type, isNotNull);
      }
    });

    test('tracks frame range from trace events', () {
      processor.processTrackEvents(trackEvents);
      expect(processor.frameRangeFromTimelineEvents, equals(const Range(2, 6)));
      expect(processor.hasProcessedEventsForFrame(1), isFalse);
      expect(processor.hasProcessedEventsForFrame(2), isTrue);
      expect(processor.hasProcessedEventsForFrame(4), isTrue);
      expect(processor.hasProcessedEventsForFrame(6), isTrue);
      expect(processor.hasProcessedEventsForFrame(7), isFalse);
    });

    test('clear', () {
      processor.processTrackEvents(trackEvents);
      expect(processor.frameRangeFromTimelineEvents, equals(const Range(2, 6)));

      processor.clear();
      expect(processor.frameRangeFromTimelineEvents, isNull);
      expect(processor.hasProcessedEventsForFrame(2), isFalse);
      expect(processor.hasProcessedEventsForFrame(4), isFalse);
      expect(processor.hasProcessedEventsForFrame(6), isFalse);

      expect(processor.uiTrackId, isNotNull);
      expect(processor.rasterTrackId, isNotNull);
    });

    test('dispose clears track ids', () {
      processor.processTrackEvents(trackEvents);
      expect(processor.frameRangeFromTimelineEvents, equals(const Range(2, 6)));

      processor.dispose();
      expect(processor.frameRangeFromTimelineEvents, isNull);
      expect(processor.hasProcessedEventsForFrame(2), isFalse);
      expect(processor.hasProcessedEventsForFrame(4), isFalse);
      expect(processor.hasProcessedEventsForFrame(6), isFalse);

      expect(processor.uiTrackId, null);
      expect(processor.rasterTrackId, null);
    });
  });
}

class TestTimelineEventsController extends TimelineEventsController {
  TestTimelineEventsController(super.performanceController);

  final List<FlutterTimelineEvent> events = [];

  @override
  void addTimelineEvent(FlutterTimelineEvent event) {
    events.add(event);
  }
}
