// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:devtools/src/timeline/timeline_controller.dart';
import 'package:devtools/src/timeline/timeline_model.dart';
import 'package:devtools/src/timeline/timeline_protocol.dart';
import 'package:devtools/src/utils.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'support/test_utils.dart';
import 'support/timeline_test_data.dart';

void main() {
  final originalGoldenUiEvent = goldenUiTimelineEvent.deepCopy();
  final originalGoldenGpuEvent = goldenGpuTimelineEvent.deepCopy();
  final originalGoldenUiTraceEvents = List.of(goldenUiTraceEvents);
  final originalGoldenGpuTraceEvents = List.of(goldenGpuTraceEvents);

  setUp(() {
    // If any of these expect statements fail, a golden was modified while the
    // tests were running. Do not modify the goldens. Instead, make a copy and
    // modify the copy.
    expect(goldenUiString() == originalGoldenUiEvent.toString(), isTrue);
    expect(goldenGpuString() == originalGoldenGpuEvent.toString(), isTrue);
    expect(
      collectionEquals(goldenUiTraceEvents, originalGoldenUiTraceEvents),
      isTrue,
    );
    expect(
      collectionEquals(goldenGpuTraceEvents, originalGoldenGpuTraceEvents),
      isTrue,
    );
  });

  group('TimelineProtocol', () {
    TimelineProtocol timelineProtocol;

    setUp(() {
      timelineProtocol = TimelineProtocol(
        uiThreadId: testUiThreadId,
        gpuThreadId: testGpuThreadId,
        timelineController: MockTimelineController(),
      );
    });

    test('infers correct trace event type', () {
      final uiEvent = goldenUiTraceEvents.first;
      final gpuEvent = goldenGpuTraceEvents.first;
      final unknownEvent = testTraceEvent({
        'name': 'Random Event We Should Not Process',
        'cat': 'Embedder',
        'tid': testUnknownThreadId,
        'pid': 2871,
        'ts': 9193106475,
        'ph': 'B',
        'args': {}
      });

      expect(uiEvent.type, equals(TimelineEventType.unknown));
      expect(gpuEvent.type, equals(TimelineEventType.unknown));
      expect(unknownEvent.type, equals(TimelineEventType.unknown));
      timelineProtocol.processTraceEvent(uiEvent);
      timelineProtocol.processTraceEvent(gpuEvent);
      timelineProtocol.processTraceEvent(unknownEvent);
      expect(uiEvent.type, equals(TimelineEventType.ui));
      expect(gpuEvent.type, equals(TimelineEventType.gpu));
      expect(unknownEvent.type, equals(TimelineEventType.unknown));
    });

    test('creates one new frame per id', () {
      // Start event followed by end event.
      timelineProtocol.processTraceEvent(frameStartEvent);
      expect(timelineProtocol.pendingFrames.length, equals(1));
      expect(timelineProtocol.pendingFrames.containsKey('PipelineItem-f1'),
          isTrue);
      timelineProtocol.processTraceEvent(frameEndEvent);
      expect(timelineProtocol.pendingFrames.length, equals(1));

      timelineProtocol.pendingFrames.clear();

      // End event followed by start event.
      timelineProtocol.processTraceEvent(frameEndEvent);
      expect(timelineProtocol.pendingFrames.length, equals(1));
      expect(timelineProtocol.pendingFrames.containsKey('PipelineItem-f1'),
          isTrue);
      timelineProtocol.processTraceEvent(frameStartEvent);
      expect(timelineProtocol.pendingFrames.length, equals(1));
    });

    test('duration trace events form timeline event tree', () async {
      expect(timelineProtocol.pendingEvents, isEmpty);
      goldenUiTraceEvents.forEach(timelineProtocol.processTraceEvent);

      await delayForEventProcessing();

      expect(timelineProtocol.pendingEvents.length, equals(1));
      final processedUiEvent = timelineProtocol.pendingEvents.first;
      expect(processedUiEvent.toString(), equals(goldenUiString()));
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
      expect(
          timelineProtocol.eventOccursWithinFrameBounds(event, frame), isTrue);

      // Event fits within epsilon of frame start.
      event.time = TimeRange()
        ..start = Duration(
            microseconds: frameStartTime - traceEventEpsilon.inMicroseconds)
        ..end = const Duration(microseconds: 5000);
      expect(
          timelineProtocol.eventOccursWithinFrameBounds(event, frame), isTrue);

      // Event does not fit within epsilon of frame start.
      event.time = TimeRange()
        ..start = Duration(
            microseconds: frameStartTime - traceEventEpsilon.inMicroseconds - 1)
        ..end = const Duration(microseconds: 5000);
      expect(
          timelineProtocol.eventOccursWithinFrameBounds(event, frame), isFalse);

      // Event with small duration uses smaller epsilon.
      event.time = TimeRange()
        ..start = const Duration(microseconds: frameStartTime - 100)
        ..end = const Duration(microseconds: frameStartTime + 100);
      expect(
          timelineProtocol.eventOccursWithinFrameBounds(event, frame), isTrue);

      event.time = TimeRange()
        ..start = const Duration(microseconds: frameStartTime - 101)
        ..end = const Duration(microseconds: frameStartTime + 100);
      expect(
          timelineProtocol.eventOccursWithinFrameBounds(event, frame), isFalse);

      // Event fits within epsilon of frame end.
      event.time = TimeRange()
        ..start = const Duration(microseconds: frameStartTime - 101)
        ..end = Duration(
            microseconds: frameEndTime + traceEventEpsilon.inMicroseconds);
      expect(
          timelineProtocol.eventOccursWithinFrameBounds(event, frame), isTrue);

      // Event does not fit within epsilon of frame end.
      event.time = TimeRange()
        ..start = const Duration(microseconds: frameStartTime - 101)
        ..end = Duration(
            microseconds: frameEndTime + traceEventEpsilon.inMicroseconds + 1);
      expect(
          timelineProtocol.eventOccursWithinFrameBounds(event, frame), isFalse);

      // Satisfies UI / GPU order.
      final uiEvent = event
        ..time = (TimeRange()
          ..start = const Duration(microseconds: 5000)
          ..end = const Duration(microseconds: 6000));
      final gpuEvent = goldenGpuTimelineEvent.deepCopy()
        ..time = (TimeRange()
          ..start = const Duration(microseconds: 4000)
          ..end = const Duration(microseconds: 8000));

      expect(timelineProtocol.eventOccursWithinFrameBounds(uiEvent, frame),
          isTrue);
      expect(timelineProtocol.eventOccursWithinFrameBounds(gpuEvent, frame),
          isTrue);

      frame.setEventFlow(uiEvent, type: TimelineEventType.ui);
      expect(timelineProtocol.eventOccursWithinFrameBounds(gpuEvent, frame),
          isFalse);

      frame = TimelineFrame('frameId')
        ..pipelineItemTime.start = const Duration(microseconds: frameStartTime)
        ..pipelineItemTime.end = const Duration(microseconds: frameEndTime);

      frame
        ..setEventFlow(null, type: TimelineEventType.ui)
        ..setEventFlow(gpuEvent, type: TimelineEventType.gpu);
      expect(timelineProtocol.eventOccursWithinFrameBounds(uiEvent, frame),
          isFalse);
    });

    test('frame completed', () async {
      expect(timelineProtocol.pendingEvents, isEmpty);
      goldenUiTraceEvents.forEach(timelineProtocol.processTraceEvent);
      await delayForEventProcessing();
      expect(timelineProtocol.pendingEvents.length, equals(1));

      expect(timelineProtocol.pendingFrames.length, equals(0));
      timelineProtocol.processTraceEvent(frameStartEvent);
      timelineProtocol.processTraceEvent(frameEndEvent);
      expect(timelineProtocol.pendingFrames.length, equals(1));
      expect(timelineProtocol.pendingEvents, isEmpty);

      final frame = timelineProtocol.pendingFrames.values.first;
      expect(frame.addedToTimeline, isNull);

      goldenGpuTraceEvents.forEach(timelineProtocol.processTraceEvent);
      await delayForEventProcessing();
      expect(timelineProtocol.pendingEvents.length, equals(0));
      expect(timelineProtocol.pendingFrames.length, equals(0));
      expect(frame.uiEventFlow.toString(), equals(goldenUiString()));
      expect(frame.gpuEventFlow.toString(), equals(goldenGpuString()));
      expect(frame.addedToTimeline, isTrue);
    });

    test('handles out of order timestamps', () async {
      final List<TraceEvent> traceEvents = List.of(goldenUiTraceEvents);
      traceEvents.reversed.forEach(timelineProtocol.processTraceEvent);
      await delayForEventProcessing();
      expect(timelineProtocol.pendingEvents.length, equals(1));
      expect(timelineProtocol.pendingEvents.first.toString(),
          equals(goldenUiString()));
    });

    test('handles trace event duplicates', () async {
      // Duplicate duration begin event.
      // VSYNC
      //  Animator::BeginFrame
      //   Animator::BeginFrame
      //     ...
      //  Animator::BeginFrame
      // VSYNC
      List<TraceEvent> traceEvents = List.of(goldenUiTraceEvents);
      traceEvents.insert(1, goldenUiTraceEvents[1]);

      traceEvents.forEach(timelineProtocol.processTraceEvent);
      await delayForEventProcessing();
      expect(timelineProtocol.pendingEvents.length, equals(1));
      expect(timelineProtocol.pendingEvents.first.toString(),
          equals(goldenUiString()));

      timelineProtocol.pendingEvents.clear();

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

      traceEvents.forEach(timelineProtocol.processTraceEvent);
      await delayForEventProcessing();
      expect(timelineProtocol.pendingEvents.length, equals(1));
      expect(timelineProtocol.pendingEvents.first.toString(),
          equals(goldenUiString()));

      timelineProtocol.pendingEvents.clear();

      // Unrecoverable state resets event tracking.
      // VSYNC
      //  Animator::BeginFrame
      //   VSYNC
      //    Animator::BeginFrame
      //     ...
      //  Animator::BeginFrame
      // VSYNC
      final vsyncEvent = testTraceEvent({
        'name': 'VSYNC',
        'cat': 'Embedder',
        'tid': testUiThreadId,
        'pid': 94955,
        'ts': 118039650802,
        'ph': 'B',
        'args': {}
      });
      final animatorBeginFrameEvent = testTraceEvent({
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
      traceEvents.forEach(timelineProtocol.processTraceEvent);
      await delayForEventProcessing();
      expect(timelineProtocol.pendingEvents.length, equals(0));
      expect(timelineProtocol.currentEventNodes[TimelineEventType.ui.index],
          isNull);
    });
  });
}

Future<void> delayForEventProcessing() async {
  await Future.delayed(const Duration(milliseconds: 1500));
}

class MockTimelineController extends Mock implements TimelineController {}
