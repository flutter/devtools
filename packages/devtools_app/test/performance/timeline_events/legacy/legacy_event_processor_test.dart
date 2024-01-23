// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/performance/panes/timeline_events/legacy/legacy_event_processor.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../test_infra/test_data/performance.dart';
import '../../../test_infra/utils/test_utils.dart';

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

    setGlobal(IdeTheme, IdeTheme());
    setGlobal(OfflineModeController, OfflineModeController());
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
  });

  group('$LegacyEventProcessor', () {
    late PerformanceData data;
    late MockPerformanceController mockPerformanceController;
    late TimelineEventsController timelineEventsController;
    late LegacyEventProcessor processor;

    setUp(() {
      data = PerformanceData();
      mockPerformanceController = createMockPerformanceControllerWithDefaults();
      timelineEventsController =
          TimelineEventsController(mockPerformanceController);
      when(mockPerformanceController.timelineEventsController)
          .thenReturn(timelineEventsController);
      when(mockPerformanceController.data).thenReturn(data);
      when(unawaited(mockPerformanceController.clearData()))
          .thenAnswer((_) async {
        data.clear();
        await timelineEventsController.clearData();
      });
      processor = timelineEventsController.legacyController.processor
        ..primeThreadIds(
          uiThreadId: testUiThreadId,
          rasterThreadId: testRasterThreadId,
        );
    });

    test('duration trace events form timeline event tree', () async {
      await processor.processData(goldenUiTraceEvents);

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

      await processor.processData(traceEvents);
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
      traceEvents.insert(
        goldenUiTraceEvents.length - 2,
        goldenUiTraceEvents[goldenUiTraceEvents.length - 2],
      );

      await processor.processData(traceEvents);
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
        'args': <Object?, Object?>{},
      });
      final animatorBeginFrameEvent = testTraceEventWrapper({
        'name': 'Animator::BeginFrame',
        'cat': 'Embedder',
        'tid': testUiThreadId,
        'pid': 94955,
        'ts': 118039650802,
        'ph': 'B',
        'args': <Object?, Object?>{},
      });
      traceEvents = [
        vsyncEvent,
        animatorBeginFrameEvent,
        vsyncEvent,
        animatorBeginFrameEvent,
      ];
      traceEvents
          .addAll(goldenUiTraceEvents.getRange(2, goldenUiTraceEvents.length));
      traceEvents.insert(2, goldenUiTraceEvents[0]);
      traceEvents.insert(3, goldenUiTraceEvents[1]);

      await processor.processData(traceEvents);
      expect(
        processor.currentDurationEventNodes[TimelineEventType.ui.index],
        isNull,
      );
    });

    test('processes all events', () async {
      final traceEvents = <TraceEventWrapper>[
        ...asyncTraceEvents,
        ...goldenUiTraceEvents,
        ...goldenRasterTraceEvents,
      ]..sort();

      final events = processor.performanceController.data!.timelineEvents;

      expect(
        events,
        isEmpty,
      );
      await processor.processData(traceEvents);
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
      final traceEvents = <TraceEventWrapper>[
        ...goldenUiTraceEvents,
        ...goldenRasterTraceEvents,
      ]..sort();

      final events = processor.performanceController.data!.timelineEvents;

      await processor.processData(traceEvents);
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
      await processor.processData(durationEventsWithDuplicateTraces);
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
        await processor.processData(asyncEventsWithChildrenWithDifferentIds);
      },
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
        equals(TimelineEventType.other),
      );
    });
  });
}
