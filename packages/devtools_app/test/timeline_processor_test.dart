// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:devtools_app/src/primitives/trace_event.dart';
import 'package:devtools_app/src/primitives/utils.dart';
import 'package:devtools_app/src/screens/performance/performance_controller.dart';
import 'package:devtools_app/src/screens/performance/performance_model.dart';
import 'package:devtools_app/src/screens/performance/timeline_event_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'test_data/performance_test_data.dart';
import 'test_utils/test_utils.dart';

void main() {
  final originalGoldenUiEvent = goldenUiTimelineEvent.deepCopy();
  final originalGoldenGpuEvent = goldenRasterTimelineEvent.deepCopy();
  final originalGoldenUiTraceEvents = List.of(goldenUiTraceEvents);
  final originalGoldenGpuTraceEvents = List.of(goldenRasterTraceEvents);

  setUp(() {
    // If any of these expect statements fail, a golden was modified while the
    // tests were running. Do not modify the goldens. Instead, make a copy and
    // modify the copy.
    expect(originalGoldenUiEvent.toString(), equals(goldenUiString));
    expect(originalGoldenGpuEvent.toString(), equals(goldenRasterString));
    expect(
      collectionEquals(goldenUiTraceEvents, originalGoldenUiTraceEvents),
      isTrue,
    );
    expect(
      collectionEquals(goldenRasterTraceEvents, originalGoldenGpuTraceEvents),
      isTrue,
    );
  });

  group('TimelineProcessor', () {
    late TimelineEventProcessor processor;

    setUp(() {
      processor = TimelineEventProcessor(MockTimelineController())
        ..primeThreadIds(
          uiThreadId: testUiThreadId,
          rasterThreadId: testRasterThreadId,
        );
    });

    test('duration trace events form timeline event tree', () async {
      await processor.processTraceEvents(goldenUiTraceEvents);

      final processedUiEvent =
          processor.performanceController.data!.timelineEvents.first;
      expect(processedUiEvent.toString(), equals(goldenUiString));
    });

    test('handles trace event duplicates', () async {
      // Duplicate duration begin event.
      // VSYNC
      //  Animator::BeginFrame
      //   Animator::BeginFrame
      //     ...
      //  Animator::BeginFrame
      // VSYNC
      var traceEvents = List.of(goldenUiTraceEvents);
      traceEvents.insert(1, goldenUiTraceEvents[1]);
      final events = processor.performanceController.data!.timelineEvents;

      await processor.processTraceEvents(traceEvents);
      expect(events.length, equals(1));
      expect(
        events.first.toString(),
        equals(goldenUiString),
      );

      await processor.performanceController.clearData();
      processor.reset();

      // Duplicate duration end event.
      // VSYNC
      //  Animator::BeginFrame
      //     ...
      //   Animator::BeginFrame
      //  Animator::BeginFrame
      // VSYNC
      traceEvents = List.of(goldenUiTraceEvents);
      traceEvents.insert(goldenUiTraceEvents.length - 2,
          goldenUiTraceEvents[goldenUiTraceEvents.length - 2]);

      await processor.processTraceEvents(traceEvents);
      expect(events.length, equals(1));
      expect(
        events.first.toString(),
        equals(goldenUiString),
      );

      await processor.performanceController.clearData();
      processor.reset();

      // Unrecoverable state resets event tracking.
      // VSYNC
      //  Animator::BeginFrame
      //   VSYNC
      //    Animator::BeginFrame
      //     ...
      //  Animator::BeginFrame
      // VSYNC
      final vsyncEvent = testTraceEventWrapper({
        'name': 'VSYNC',
        'cat': 'Embedder',
        'tid': testUiThreadId,
        'pid': 94955,
        'ts': 118039650802,
        'ph': 'B',
        'args': {}
      });
      final animatorBeginFrameEvent = testTraceEventWrapper({
        'name': 'Animator::BeginFrame',
        'cat': 'Embedder',
        'tid': testUiThreadId,
        'pid': 94955,
        'ts': 118039650802,
        'ph': 'B',
        'args': {}
      });
      traceEvents = [
        vsyncEvent,
        animatorBeginFrameEvent,
        vsyncEvent,
        animatorBeginFrameEvent
      ];
      traceEvents
          .addAll(goldenUiTraceEvents.getRange(2, goldenUiTraceEvents.length));
      traceEvents.insert(2, goldenUiTraceEvents[0]);
      traceEvents.insert(3, goldenUiTraceEvents[1]);

      await processor.processTraceEvents(traceEvents);
      expect(
        processor.currentDurationEventNodes[TimelineEventType.ui.index],
        isNull,
      );
    });

    test('processes all events', () async {
      final traceEvents = [
        ...asyncTraceEvents,
        ...goldenUiTraceEvents,
        ...goldenRasterTraceEvents,
      ]..sort();

      final events = processor.performanceController.data!.timelineEvents;

      expect(
        events,
        isEmpty,
      );
      await processor.processTraceEvents(traceEvents);
      expect(
        events.length,
        equals(4),
      );
      expect(
        events[0].toString(),
        equals(goldenAsyncString),
      );
      expect(
        events[1].toString(),
        equals('  D [193937061035 μs - 193938741076 μs]\n'),
      );
      expect(
        events[2].toString(),
        equals(goldenUiString),
      );
      expect(
        events[3].toString(),
        equals(goldenRasterString),
      );
    });

    test('tracks flutter frame identifier events', () async {
      final traceEvents = [
        ...goldenUiTraceEvents,
        ...goldenRasterTraceEvents,
      ]..sort();

      final events = processor.performanceController.data!.timelineEvents;

      await processor.processTraceEvents(traceEvents);
      expect(
        events.length,
        equals(2),
      );
      expect(
        events[0].toString(),
        equals(goldenUiString),
      );
      expect(
        events[1].toString(),
        equals(goldenRasterString),
      );

      final uiEvent = events[0] as SyncTimelineEvent;
      final rasterEvent = events[1] as SyncTimelineEvent;
      expect(uiEvent.uiFrameEvents.length, equals(1));
      expect(uiEvent.rasterFrameEvents, isEmpty);
      expect(rasterEvent.uiFrameEvents, isEmpty);
      expect(rasterEvent.rasterFrameEvents.length, equals(1));
    });

    test('processes trace with duplicate events', () async {
      final events = processor.performanceController.data!.timelineEvents;
      expect(
        events,
        isEmpty,
      );
      await processor.processTraceEvents(durationEventsWithDuplicateTraces);
      // If the processor is not handling duplicates properly, this value would
      // be 0.
      expect(
        events.length,
        equals(1),
      );
    });

    test(
        'processes trace with children with different ids does not throw assert',
        () async {
      // This test should complete without throwing an assert from
      // `AsyncTimelineEvent.endAsyncEvent`.
      await processor
          .processTraceEvents(asyncEventsWithChildrenWithDifferentIds);
    });

    test('inferEventType', () {
      expect(
        processor.inferEventType(asyncStartATrace.event),
        equals(TimelineEventType.async),
      );
      expect(
        processor.inferEventType(asyncEndATrace.event),
        equals(TimelineEventType.async),
      );
      expect(
        processor.inferEventType(vsyncTrace.event),
        equals(TimelineEventType.ui),
      );
      expect(
        processor.inferEventType(gpuRasterizerDrawTrace.event),
        equals(TimelineEventType.raster),
      );
      expect(
        processor.inferEventType(unknownEventBeginTrace.event),
        equals(TimelineEventType.other),
      );
    });
  });
}

class MockTimelineController extends Mock implements PerformanceController {
  @override
  final data = PerformanceData();

  @override
  void addTimelineEvent(TimelineEvent event) {
    data!.addTimelineEvent(event);
  }

  @override
  void addFrame(FlutterFrame frame) {
    data!.frames.add(frame);
  }

  @override
  Future<void> clearData({bool clearVmTimeline = true}) async {
    data!.clear();
  }
}
