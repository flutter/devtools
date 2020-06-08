// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/timeline/timeline_controller.dart';
import 'package:devtools_app/src/timeline/timeline_model.dart';
import 'package:devtools_app/src/timeline/timeline_processor.dart';
import 'package:devtools_app/src/trace_event.dart';
import 'package:devtools_app/src/utils.dart';
import 'package:devtools_testing/support/test_utils.dart';
import 'package:devtools_testing/support/timeline_test_data.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

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
    TimelineProcessor processor;

    setUp(() {
      processor = TimelineProcessor(MockTimelineController())
        ..primeThreadIds(
          uiThreadId: testUiThreadId,
          rasterThreadId: testRasterThreadId,
        );
    });

    test('creates one new frame per id', () async {
      await processor.processTimeline(
        [frameStartEvent, frameEndEvent],
        resetAfterProcessing: false,
      );
      expect(processor.pendingFrames.length, equals(1));
      expect(processor.pendingFrames.containsKey('PipelineItem-f1'), isTrue);
    });

    test('duration trace events form timeline event tree', () async {
      await processor.processTimeline(goldenUiTraceEvents);

      final processedUiEvent =
          processor.timelineController.data.timelineEvents.first;
      expect(processedUiEvent.toString(), equals(goldenUiString));
    });

    test('frame events satisfy ui gpu order', () {
      const frameStartTime = 2000;
      const frameEndTime = 8000;
      TimelineFrame frame = TimelineFrame('frameId')
        ..pipelineItemTime.start = const Duration(microseconds: frameStartTime)
        ..pipelineItemTime.end = const Duration(microseconds: frameEndTime);

      // Satisfies UI / GPU order.
      final uiEvent = goldenUiTimelineEvent.deepCopy()
        ..time = (TimeRange()
          ..start = const Duration(microseconds: 5000)
          ..end = const Duration(microseconds: 6000));
      final gpuEvent = goldenRasterTimelineEvent.deepCopy()
        ..time = (TimeRange()
          ..start = const Duration(microseconds: 4000)
          ..end = const Duration(microseconds: 8000));

      expect(processor.satisfiesUiRasterOrder(uiEvent, frame), isTrue);
      expect(processor.satisfiesUiRasterOrder(gpuEvent, frame), isTrue);

      frame.setEventFlow(uiEvent, type: TimelineEventType.ui);
      expect(processor.satisfiesUiRasterOrder(gpuEvent, frame), isFalse);

      frame = TimelineFrame('frameId')
        ..pipelineItemTime.start = const Duration(microseconds: frameStartTime)
        ..pipelineItemTime.end = const Duration(microseconds: frameEndTime);

      frame
        ..setEventFlow(null, type: TimelineEventType.ui)
        ..setEventFlow(gpuEvent, type: TimelineEventType.raster);
      expect(processor.satisfiesUiRasterOrder(uiEvent, frame), isFalse);
    });

    test('frame completed', () async {
      await processor.processTimeline([
        frameStartEvent,
        ...goldenUiTraceEvents,
        ...goldenRasterTraceEvents,
        frameEndEvent,
      ]);
      expect(processor.pendingFrames.length, equals(0));
      expect(processor.timelineController.data.frames.length, equals(1));

      final frame = processor.timelineController.data.frames.first;
      expect(frame.uiEventFlow.toString(), equals(goldenUiString));
      expect(frame.rasterEventFlow.toString(), equals(goldenRasterString));
      expect(frame.isReadyForTimeline, isTrue);
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

      await processor.processTimeline(traceEvents);
      expect(
          processor.timelineController.data.timelineEvents.length, equals(1));
      expect(
        processor.timelineController.data.timelineEvents.first.toString(),
        equals(goldenUiString),
      );

      await processor.timelineController.clearData();

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

      await processor.processTimeline(traceEvents);
      expect(
          processor.timelineController.data.timelineEvents.length, equals(1));
      expect(
        processor.timelineController.data.timelineEvents.first.toString(),
        equals(goldenUiString),
      );

      await processor.timelineController.clearData();

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

      await processor.processTimeline(traceEvents);
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
      ];
      expect(
        processor.timelineController.data.timelineEvents,
        isEmpty,
      );
      await processor.processTimeline(traceEvents);
      expect(
        processor.timelineController.data.timelineEvents.length,
        equals(4),
      );
      expect(
        processor.timelineController.data.timelineEvents[0].toString(),
        equals(goldenUiString),
      );
      expect(
        processor.timelineController.data.timelineEvents[1].toString(),
        equals(goldenRasterString),
      );
      expect(
        processor.timelineController.data.timelineEvents[2].toString(),
        equals(goldenAsyncString),
      );
      expect(
        processor.timelineController.data.timelineEvents[3].toString(),
        equals('  D [193937061035 μs - 193938741076 μs]\n'),
      );
    });

    test('processes trace with duplicate events', () async {
      expect(
        processor.timelineController.data.timelineEvents,
        isEmpty,
      );
      await processor.processTimeline(durationEventsWithDuplicateTraces);
      // If the processor is not handling duplicates properly, this value would
      // be 0.
      expect(
        processor.timelineController.data.timelineEvents.length,
        equals(1),
      );
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
        equals(TimelineEventType.unknown),
      );
    });
  });
}

class MockTimelineController extends Mock implements TimelineController {
  @override
  final data = TimelineData();

  @override
  void addTimelineEvent(TimelineEvent event) {
    data.addTimelineEvent(event);
  }

  @override
  void addFrame(TimelineFrame frame) {
    data.frames.add(frame);
  }

  @override
  Future<void> clearData({bool clearVmTimeline = true}) async {
    data.clear();
  }
}
