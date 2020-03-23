// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/timeline/html_timeline_controller.dart';
import 'package:devtools_app/src/timeline/html_timeline_model.dart';
import 'package:devtools_app/src/timeline/html_timeline_processor.dart';
import 'package:devtools_app/src/trace_event.dart';
import 'package:devtools_app/src/utils.dart';
import 'package:devtools_testing/support/test_utils.dart';
import 'package:devtools_testing/support/timeline_test_data.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

void main() {
  final originalGoldenUiEvent = goldenUiTimelineEvent.deepCopy();
  final originalGoldenGpuEvent = goldenGpuTimelineEvent.deepCopy();
  final originalGoldenUiTraceEvents = List.of(goldenUiTraceEvents);
  final originalGoldenGpuTraceEvents = List.of(goldenGpuTraceEvents);

  setUp(() {
    // If any of these expect statements fail, a golden was modified while the
    // tests were running. Do not modify the goldens. Instead, make a copy and
    // modify the copy.
    expect(originalGoldenUiEvent.toString(), equals(goldenUiString));
    expect(originalGoldenGpuEvent.toString(), equals(goldenGpuString));
    expect(
      collectionEquals(goldenUiTraceEvents, originalGoldenUiTraceEvents),
      isTrue,
    );
    expect(
      collectionEquals(goldenGpuTraceEvents, originalGoldenGpuTraceEvents),
      isTrue,
    );
  });

  group('FrameBasedTimelineProcessor', () {
    FrameBasedTimelineProcessor processor;

    setUp(() {
      processor = FrameBasedTimelineProcessor(MockTimelineController())
        ..primeThreadIds(
          uiThreadId: testUiThreadId,
          gpuThreadId: testGpuThreadId,
        );
    });

    test('creates one new frame per id', () {
      // Start event followed by end event.
      processor.processTraceEvent(frameStartEvent);
      expect(processor.pendingFrames.length, equals(1));
      expect(processor.pendingFrames.containsKey('PipelineItem-f1'), isTrue);
      processor.processTraceEvent(frameEndEvent);
      expect(processor.pendingFrames.length, equals(1));

      processor.pendingFrames.clear();

      // End event followed by start event.
      processor.processTraceEvent(frameEndEvent);
      expect(processor.pendingFrames.length, equals(1));
      expect(processor.pendingFrames.containsKey('PipelineItem-f1'), isTrue);
      processor.processTraceEvent(frameStartEvent);
      expect(processor.pendingFrames.length, equals(1));
    });

    test('duration trace events form timeline event tree', () async {
      expect(processor.pendingEvents, isEmpty);
      goldenUiTraceEvents.forEach(processor.processTraceEvent);

      await delayForEventProcessing();

      expect(processor.pendingEvents.length, equals(1));
      final processedUiEvent = processor.pendingEvents.first;
      expect(processedUiEvent.toString(), equals(goldenUiString));
    });

    test('event occurs within frame boundaries', () {
      const frameStartTime = 2000;
      const frameEndTime = 8000;
      TimelineFrame frame = TimelineFrame('frameId')
        ..pipelineItemTime.start = const Duration(microseconds: frameStartTime)
        ..pipelineItemTime.end = const Duration(microseconds: frameEndTime);

      final event = goldenUiTimelineEvent.deepCopy()
        ..time = (TimeRange()
          ..start = const Duration(microseconds: frameStartTime)
          ..end = const Duration(microseconds: 5000));

      // Event fits within frame timestamps.
      expect(processor.eventOccursWithinFrameBounds(event, frame), isTrue);

      // Event fits within epsilon of frame start.
      event.time = TimeRange()
        ..start = Duration(
            microseconds: frameStartTime - traceEventEpsilon.inMicroseconds)
        ..end = const Duration(microseconds: 5000);
      expect(processor.eventOccursWithinFrameBounds(event, frame), isTrue);

      // Event does not fit within epsilon of frame start.
      event.time = TimeRange()
        ..start = Duration(
            microseconds: frameStartTime - traceEventEpsilon.inMicroseconds - 1)
        ..end = const Duration(microseconds: 5000);
      expect(processor.eventOccursWithinFrameBounds(event, frame), isFalse);

      // Event with small duration uses smaller epsilon.
      event.time = TimeRange()
        ..start = const Duration(microseconds: frameStartTime - 100)
        ..end = const Duration(microseconds: frameStartTime + 100);
      expect(processor.eventOccursWithinFrameBounds(event, frame), isTrue);

      event.time = TimeRange()
        ..start = const Duration(microseconds: frameStartTime - 101)
        ..end = const Duration(microseconds: frameStartTime + 100);
      expect(processor.eventOccursWithinFrameBounds(event, frame), isFalse);

      // Event fits within epsilon of frame end.
      event.time = TimeRange()
        ..start = const Duration(microseconds: frameStartTime - 101)
        ..end = Duration(
            microseconds: frameEndTime + traceEventEpsilon.inMicroseconds);
      expect(processor.eventOccursWithinFrameBounds(event, frame), isTrue);

      // Event does not fit within epsilon of frame end.
      event.time = TimeRange()
        ..start = const Duration(microseconds: frameStartTime - 101)
        ..end = Duration(
            microseconds: frameEndTime + traceEventEpsilon.inMicroseconds + 1);
      expect(processor.eventOccursWithinFrameBounds(event, frame), isFalse);

      // Satisfies UI / GPU order.
      final uiEvent = event
        ..time = (TimeRange()
          ..start = const Duration(microseconds: 5000)
          ..end = const Duration(microseconds: 6000));
      final gpuEvent = goldenGpuTimelineEvent.deepCopy()
        ..time = (TimeRange()
          ..start = const Duration(microseconds: 4000)
          ..end = const Duration(microseconds: 8000));

      expect(processor.eventOccursWithinFrameBounds(uiEvent, frame), isTrue);
      expect(processor.eventOccursWithinFrameBounds(gpuEvent, frame), isTrue);

      frame.setEventFlow(uiEvent, type: TimelineEventType.ui);
      expect(processor.eventOccursWithinFrameBounds(gpuEvent, frame), isFalse);

      frame = TimelineFrame('frameId')
        ..pipelineItemTime.start = const Duration(microseconds: frameStartTime)
        ..pipelineItemTime.end = const Duration(microseconds: frameEndTime);

      frame
        ..setEventFlow(null, type: TimelineEventType.ui)
        ..setEventFlow(gpuEvent, type: TimelineEventType.raster);
      expect(processor.eventOccursWithinFrameBounds(uiEvent, frame), isFalse);
    });

    test('frame completed', () async {
      expect(processor.pendingEvents, isEmpty);
      goldenUiTraceEvents.forEach(processor.processTraceEvent);
      await delayForEventProcessing();
      expect(processor.pendingEvents.length, equals(1));

      expect(processor.pendingFrames.length, equals(0));
      processor.processTraceEvent(frameStartEvent);
      processor.processTraceEvent(frameEndEvent);
      expect(processor.pendingFrames.length, equals(1));
      expect(processor.pendingEvents, isEmpty);

      final frame = processor.pendingFrames.values.first;
      expect(frame.addedToTimeline, isNull);

      goldenGpuTraceEvents.forEach(processor.processTraceEvent);
      await delayForEventProcessing();
      expect(processor.pendingEvents.length, equals(0));
      expect(processor.pendingFrames.length, equals(0));
      expect(frame.uiEventFlow.toString(), equals(goldenUiString));
      expect(frame.gpuEventFlow.toString(), equals(goldenGpuString));
      expect(frame.addedToTimeline, isTrue);
    });

    test('handles out of order timestamps', () async {
      final traceEvents = List.of(goldenUiTraceEvents);
      traceEvents.reversed.forEach(processor.processTraceEvent);
      await delayForEventProcessing();
      expect(processor.pendingEvents.length, equals(1));
      expect(processor.pendingEvents.first.toString(), equals(goldenUiString));
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

      traceEvents.forEach(processor.processTraceEvent);
      await delayForEventProcessing();
      expect(processor.pendingEvents.length, equals(1));
      expect(processor.pendingEvents.first.toString(), equals(goldenUiString));

      processor.pendingEvents.clear();

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

      traceEvents.forEach(processor.processTraceEvent);
      await delayForEventProcessing();
      expect(processor.pendingEvents.length, equals(1));
      expect(processor.pendingEvents.first.toString(), equals(goldenUiString));

      processor.pendingEvents.clear();

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
      traceEvents.forEach(processor.processTraceEvent);
      await delayForEventProcessing();
      expect(processor.pendingEvents.length, equals(0));
      expect(processor.currentEventNodes[TimelineEventType.ui.index], isNull);
    });
  });

  group('FullTimelineProcessor', () {
    FullTimelineProcessor processor;

    final traceEvents = [
      ...asyncTraceEvents,
      ...goldenUiTraceEvents,
      ...goldenGpuTraceEvents,
    ];

    setUp(() {
      processor = FullTimelineProcessor(MockTimelineController())
        ..primeThreadIds(
          uiThreadId: testUiThreadId,
          gpuThreadId: testGpuThreadId,
        );
    });

    test('processes all events', () async {
      expect(
        processor.timelineController.fullTimeline.data.timelineEvents,
        isEmpty,
      );
      await processor.processTimeline(traceEvents);
      expect(
        processor.timelineController.fullTimeline.data.timelineEvents.length,
        equals(4),
      );
      expect(
        processor.timelineController.fullTimeline.data.timelineEvents[0]
            .toString(),
        equals(goldenUiString),
      );
      expect(
        processor.timelineController.fullTimeline.data.timelineEvents[1]
            .toString(),
        equals(goldenGpuString),
      );
      expect(
        processor.timelineController.fullTimeline.data.timelineEvents[2]
            .toString(),
        equals(goldenAsyncString),
      );
      expect(
        processor.timelineController.fullTimeline.data.timelineEvents[3]
            .toString(),
        equals('  D [193937061035 μs - 193938741076 μs]\n'),
      );
    });

    test('processes trace with duplicate events', () async {
      expect(
        processor.timelineController.fullTimeline.data.timelineEvents,
        isEmpty,
      );
      await processor.processTimeline(durationEventsWithDuplicateTraces);
      // If the processor is not handling duplicates properly, this value would
      // be 0.
      expect(
        processor.timelineController.fullTimeline.data.timelineEvents.length,
        equals(1),
      );
    });
  });

  group('TimelineProcessor', () {
    // [TimelineProcessor] is abstract, so it doesn't matter which implementation
    // we use for [processor].
    final processor = FullTimelineProcessor(MockTimelineController())
      ..primeThreadIds(
        uiThreadId: testUiThreadId,
        gpuThreadId: testGpuThreadId,
      );

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
        equals(TimelineEventType.unknown),
      );
    });
  });
}

Future<void> delayForEventProcessing() async {
  await Future.delayed(const Duration(milliseconds: 1500));
}

class MockTimelineController extends Mock implements TimelineController {
  @override
  final frameBasedTimeline = MockFrameBasedTimeline();

  @override
  final fullTimeline = MockFullTimeline();
}

class MockFrameBasedTimeline extends Mock implements FrameBasedTimeline {}

class MockFullTimeline extends Mock implements FullTimeline {
  @override
  final data = FullTimelineData();

  @override
  void addTimelineEvent(TimelineEvent event) {
    data.addTimelineEvent(event);
  }
}
