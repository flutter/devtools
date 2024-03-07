// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/performance/panes/timeline_events/perfetto/perfetto_event_processor.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../test_infra/test_data/performance.dart';
import '../../../test_infra/utils/test_utils.dart';

void main() {
  final originalGoldenUiTraceEvents = List.of(goldenUiTraceEvents);
  final originalGoldenGpuTraceEvents = List.of(goldenRasterTraceEvents);

  setUp(() {
    // If any of these expect statements fail, a golden was modified while the
    // tests were running. Do not modify the goldens. Instead, make a copy and
    // modify the copy.
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

  group('$PerfettoEventProcessor', () {
    late PerfettoEventProcessor processor;

    setUp(() {
      final data = PerformanceData();
      final mockPerformanceController =
          createMockPerformanceControllerWithDefaults();
      final timelineEventsController =
          TimelineEventsController(mockPerformanceController);
      when(mockPerformanceController.timelineEventsController)
          .thenReturn(timelineEventsController);
      when(mockPerformanceController.data).thenReturn(data);
      processor = timelineEventsController.perfettoController.processor
        ..primeTrackIds(
          ui: testUiThreadId,
          raster: testRasterThreadId,
        );
    });

    test('duration trace events form timeline event tree', () async {
      await processor.processData(goldenUiTraceEvents);

      final processedUiEvent =
          processor.performanceController.data!.timelineEvents.first;
      expect(processedUiEvent.toString(), equals(goldenUiString));
    });

    test('only processes synchronous events', () async {
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
      expect(events.length, equals(2));
      expect(events[0].toString(), equals(goldenUiString));
      expect(events[1].toString(), equals(goldenRasterString));
    });

    test('tracks flutter frame identifier events', () async {
      final traceEvents = <TraceEventWrapper>[
        ...goldenUiTraceEvents,
        ...goldenRasterTraceEvents,
      ]..sort();

      final events = processor.performanceController.data!.timelineEvents;

      await processor.processData(traceEvents);
      expect(events.length, equals(2));
      expect(events[0].toString(), equals(goldenUiString));
      expect(events[1].toString(), equals(goldenRasterString));

      final uiEvent = events[0] as SyncTimelineEvent;
      final rasterEvent = events[1] as SyncTimelineEvent;
      expect(uiEvent.uiFrameEvents.length, equals(1));
      expect(uiEvent.rasterFrameEvents, isEmpty);
      expect(rasterEvent.uiFrameEvents, isEmpty);
      expect(rasterEvent.rasterFrameEvents.length, equals(1));
    });

    test('tracks frame range from trace events', () async {
      final events = processor.performanceController.data!.timelineEvents;
      await processor.processData(_frameIdentifierEvents);
      expect(events.length, equals(6));
      expect(processor.frameRangeFromTimelineEvents, equals(const Range(1, 3)));
      expect(processor.hasProcessedEventsForFrame(0), isFalse);
      expect(processor.hasProcessedEventsForFrame(1), isTrue);
      expect(processor.hasProcessedEventsForFrame(2), isTrue);
      expect(processor.hasProcessedEventsForFrame(3), isTrue);
      expect(processor.hasProcessedEventsForFrame(4), isFalse);
    });

    test('reset clears frame range', () async {
      await processor.processData(_frameIdentifierEvents);
      expect(processor.frameRangeFromTimelineEvents, equals(const Range(1, 3)));

      processor.reset();
      expect(processor.frameRangeFromTimelineEvents, isNull);
      expect(processor.hasProcessedEventsForFrame(0), isFalse);
      expect(processor.hasProcessedEventsForFrame(1), isFalse);
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
  });
}

final _frameIdentifierEvents = [
  testTraceEventWrapper({
    'name': 'Animator::BeginFrame',
    'cat': 'Embedder',
    'tid': testUiThreadId,
    'pid': 94955,
    'ts': 100,
    'ph': 'B',
    'args': {'frame_number': '1'},
  }),
  testTraceEventWrapper({
    'name': 'Animator::BeginFrame',
    'cat': 'Embedder',
    'tid': testUiThreadId,
    'pid': 94955,
    'ts': 200,
    'ph': 'E',
    'args': <String, Object?>{},
  }),
  testTraceEventWrapper({
    'name': 'Animator::BeginFrame',
    'cat': 'Embedder',
    'tid': testUiThreadId,
    'pid': 94955,
    'ts': 300,
    'ph': 'B',
    'args': {'frame_number': '2'},
  }),
  testTraceEventWrapper({
    'name': 'Animator::BeginFrame',
    'cat': 'Embedder',
    'tid': testUiThreadId,
    'pid': 94955,
    'ts': 400,
    'ph': 'E',
    'args': <String, Object?>{},
  }),
  testTraceEventWrapper({
    'name': 'Animator::BeginFrame',
    'cat': 'Embedder',
    'tid': testUiThreadId,
    'pid': 94955,
    'ts': 500,
    'ph': 'B',
    'args': {'frame_number': '3'},
  }),
  testTraceEventWrapper({
    'name': 'Animator::BeginFrame',
    'cat': 'Embedder',
    'tid': testUiThreadId,
    'pid': 94955,
    'ts': 600,
    'ph': 'E',
    'args': <String, Object?>{},
  }),
  testTraceEventWrapper({
    'name': 'GPURasterizer::Draw',
    'cat': 'Embedder',
    'tid': testRasterThreadId,
    'pid': 94955,
    'ts': 150,
    'ph': 'B',
    'args': {
      'isolateId': 'id_001',
      'frame_number': '1',
    },
  }),
  testTraceEventWrapper({
    'name': 'GPURasterizer::Draw',
    'cat': 'Embedder',
    'tid': testRasterThreadId,
    'pid': 94955,
    'ts': 250,
    'ph': 'E',
    'args': <String, Object?>{},
  }),
  testTraceEventWrapper({
    'name': 'GPURasterizer::Draw',
    'cat': 'Embedder',
    'tid': testRasterThreadId,
    'pid': 94955,
    'ts': 350,
    'ph': 'B',
    'args': {
      'isolateId': 'id_001',
      'frame_number': '2',
    },
  }),
  testTraceEventWrapper({
    'name': 'GPURasterizer::Draw',
    'cat': 'Embedder',
    'tid': testRasterThreadId,
    'pid': 94955,
    'ts': 450,
    'ph': 'E',
    'args': <String, Object?>{},
  }),
  testTraceEventWrapper({
    'name': 'GPURasterizer::Draw',
    'cat': 'Embedder',
    'tid': testRasterThreadId,
    'pid': 94955,
    'ts': 550,
    'ph': 'B',
    'args': {
      'isolateId': 'id_001',
      'frame_number': '3',
    },
  }),
  testTraceEventWrapper({
    'name': 'GPURasterizer::Draw',
    'cat': 'Embedder',
    'tid': testRasterThreadId,
    'pid': 94955,
    'ts': 650,
    'ph': 'E',
    'args': <String, Object?>{},
  }),
];
