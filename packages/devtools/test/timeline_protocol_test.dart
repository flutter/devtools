// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:devtools/src/timeline/timeline_protocol.dart';
import 'package:devtools/src/utils.dart';
import 'package:test/test.dart';

import 'support/test_utils.dart';

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

  group('TimelineData', () {
    TimelineData timelineData;

    setUp(() {
      timelineData = TimelineData(
        uiThreadId: uiThreadId,
        gpuThreadId: gpuThreadId,
      );
    });

    test('infers correct trace event type', () {
      final uiEvent = goldenUiTraceEvents.first;
      final gpuEvent = goldenGpuTraceEvents.first;
      final unknownEvent = testTraceEvent({
        'name': 'Random Event We Should Not Process',
        'cat': 'Embedder',
        'tid': unknownThreadId,
        'pid': 2871,
        'ts': 9193106475,
        'ph': 'B',
        'args': {}
      });

      expect(uiEvent.type, equals(TimelineEventType.unknown));
      expect(gpuEvent.type, equals(TimelineEventType.unknown));
      expect(unknownEvent.type, equals(TimelineEventType.unknown));
      timelineData.processTraceEvent(uiEvent);
      timelineData.processTraceEvent(gpuEvent);
      timelineData.processTraceEvent(unknownEvent);
      expect(uiEvent.type, equals(TimelineEventType.ui));
      expect(gpuEvent.type, equals(TimelineEventType.gpu));
      expect(unknownEvent.type, equals(TimelineEventType.unknown));
    });

    test('creates one new frame per id', () {
      // Start event followed by end event.
      timelineData.processTraceEvent(frameStartEvent);
      expect(timelineData.pendingFrames.length, equals(1));
      expect(timelineData.pendingFrames.containsKey('PipelineItem-f1'), isTrue);
      timelineData.processTraceEvent(frameEndEvent);
      expect(timelineData.pendingFrames.length, equals(1));

      timelineData.pendingFrames.clear();

      // End event followed by start event.
      timelineData.processTraceEvent(frameEndEvent);
      expect(timelineData.pendingFrames.length, equals(1));
      expect(timelineData.pendingFrames.containsKey('PipelineItem-f1'), isTrue);
      timelineData.processTraceEvent(frameStartEvent);
      expect(timelineData.pendingFrames.length, equals(1));
    });

    test('duration trace events form timeline event tree', () async {
      expect(timelineData.pendingEvents, isEmpty);
      goldenUiTraceEvents.forEach(timelineData.processTraceEvent);

      await delayForEventProcessing();

      expect(timelineData.pendingEvents.length, equals(1));
      final processedUiEvent = timelineData.pendingEvents.first;
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
      expect(timelineData.eventOccursWithinFrameBounds(event, frame), isTrue);

      // Event fits within epsilon of frame start.
      event.time = TimeRange()
        ..start = Duration(
            microseconds: frameStartTime - traceEventEpsilon.inMicroseconds)
        ..end = const Duration(microseconds: 5000);
      expect(timelineData.eventOccursWithinFrameBounds(event, frame), isTrue);

      // Event does not fit within epsilon of frame start.
      event.time = TimeRange()
        ..start = Duration(
            microseconds: frameStartTime - traceEventEpsilon.inMicroseconds - 1)
        ..end = const Duration(microseconds: 5000);
      expect(timelineData.eventOccursWithinFrameBounds(event, frame), isFalse);

      // Event with small duration uses smaller epsilon.
      event.time = TimeRange()
        ..start = const Duration(microseconds: frameStartTime - 100)
        ..end = const Duration(microseconds: frameStartTime + 100);
      expect(timelineData.eventOccursWithinFrameBounds(event, frame), isTrue);

      event.time = TimeRange()
        ..start = const Duration(microseconds: frameStartTime - 101)
        ..end = const Duration(microseconds: frameStartTime + 100);
      expect(timelineData.eventOccursWithinFrameBounds(event, frame), isFalse);

      // Event fits within epsilon of frame end.
      event.time = TimeRange()
        ..start = const Duration(microseconds: frameStartTime - 101)
        ..end = Duration(
            microseconds: frameEndTime + traceEventEpsilon.inMicroseconds);
      expect(timelineData.eventOccursWithinFrameBounds(event, frame), isTrue);

      // Event does not fit within epsilon of frame end.
      event.time = TimeRange()
        ..start = const Duration(microseconds: frameStartTime - 101)
        ..end = Duration(
            microseconds: frameEndTime + traceEventEpsilon.inMicroseconds + 1);
      expect(timelineData.eventOccursWithinFrameBounds(event, frame), isFalse);

      // Satisfies UI / GPU order.
      final uiEvent = event
        ..time = (TimeRange()
          ..start = const Duration(microseconds: 5000)
          ..end = const Duration(microseconds: 6000));
      final gpuEvent = goldenGpuTimelineEvent.deepCopy()
        ..time = (TimeRange()
          ..start = const Duration(microseconds: 4000)
          ..end = const Duration(microseconds: 8000));

      expect(timelineData.eventOccursWithinFrameBounds(uiEvent, frame), isTrue);
      expect(
          timelineData.eventOccursWithinFrameBounds(gpuEvent, frame), isTrue);

      frame.setEventFlow(uiEvent, type: TimelineEventType.ui);
      expect(
          timelineData.eventOccursWithinFrameBounds(gpuEvent, frame), isFalse);

      frame = TimelineFrame('frameId')
        ..pipelineItemTime.start = const Duration(microseconds: frameStartTime)
        ..pipelineItemTime.end = const Duration(microseconds: frameEndTime);

      frame
        ..setEventFlow(null, type: TimelineEventType.ui)
        ..setEventFlow(gpuEvent, type: TimelineEventType.gpu);
      expect(
          timelineData.eventOccursWithinFrameBounds(uiEvent, frame), isFalse);
    });

    test('frame completed', () async {
      expect(timelineData.pendingEvents, isEmpty);
      goldenUiTraceEvents.forEach(timelineData.processTraceEvent);
      await delayForEventProcessing();
      expect(timelineData.pendingEvents.length, equals(1));

      expect(timelineData.pendingFrames.length, equals(0));
      timelineData.processTraceEvent(frameStartEvent);
      timelineData.processTraceEvent(frameEndEvent);
      expect(timelineData.pendingFrames.length, equals(1));
      expect(timelineData.pendingEvents, isEmpty);

      final frame = timelineData.pendingFrames.values.first;
      expect(frame.addedToTimeline, isNull);

      goldenGpuTraceEvents.forEach(timelineData.processTraceEvent);
      await delayForEventProcessing();
      expect(timelineData.pendingEvents.length, equals(0));
      expect(timelineData.pendingFrames.length, equals(0));
      expect(frame.uiEventFlow.toString(), equals(goldenUiString()));
      expect(frame.gpuEventFlow.toString(), equals(goldenGpuString()));
      expect(frame.addedToTimeline, isTrue);
    });

    test('handles out of order timestamps', () async {
      final List<TraceEvent> traceEvents = List.of(goldenUiTraceEvents);
      traceEvents.reversed.forEach(timelineData.processTraceEvent);
      await delayForEventProcessing();
      expect(timelineData.pendingEvents.length, equals(1));
      expect(timelineData.pendingEvents.first.toString(),
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

      traceEvents.forEach(timelineData.processTraceEvent);
      await delayForEventProcessing();
      expect(timelineData.pendingEvents.length, equals(1));
      expect(timelineData.pendingEvents.first.toString(),
          equals(goldenUiString()));

      timelineData.pendingEvents.clear();

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

      traceEvents.forEach(timelineData.processTraceEvent);
      await delayForEventProcessing();
      expect(timelineData.pendingEvents.length, equals(1));
      expect(timelineData.pendingEvents.first.toString(),
          equals(goldenUiString()));

      timelineData.pendingEvents.clear();

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
        'tid': uiThreadId,
        'pid': 94955,
        'ts': 118039650802,
        'ph': 'B',
        'args': {}
      });
      final animatorBeginFrameEvent = testTraceEvent({
        'name': 'Animator::BeginFrame',
        'cat': 'Embedder',
        'tid': uiThreadId,
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
      traceEvents.forEach(timelineData.processTraceEvent);
      await delayForEventProcessing();
      expect(timelineData.pendingEvents.length, equals(0));
      expect(
          timelineData.currentEventNodes[TimelineEventType.ui.index], isNull);
    });
  });

  group('TimelineEvent', () {
    test('get depth', () {
      expect(goldenUiTimelineEvent.depth, equals(7));
    });

    test('getRoot', () {
      expect(goldenUiTimelineEvent.getRoot(), equals(vsyncEvent));
      expect(buildEvent.getRoot(), equals(vsyncEvent));
    });

    test('containsChildWithCondition', () {
      expect(
        goldenUiTimelineEvent.containsChildWithCondition((TimelineEvent event) {
          return event.name == 'Animate';
        }),
        isTrue,
      );
      expect(
        goldenUiTimelineEvent.containsChildWithCondition((TimelineEvent event) {
          return event.beginTraceEventJson == animateEvent.beginTraceEventJson;
        }),
        isTrue,
      );
      expect(
        goldenUiTimelineEvent.containsChildWithCondition((TimelineEvent event) {
          return event.name == 'FakeEventName';
        }),
        isFalse,
      );
    });

    test('maybeRemoveDuplicate', () {
      final goldenCopy = goldenUiTimelineEvent.deepCopy();

      // Event with no duplicates should be unchanged.
      goldenCopy.maybeRemoveDuplicate();
      expect(goldenCopy.toString(), equals(goldenUiString()));

      // Add a duplicate event in [goldenCopy]'s event tree.
      final duplicateEvent = goldenCopy.deepCopy();
      duplicateEvent.parent = goldenCopy;
      duplicateEvent.children = goldenCopy.children;
      goldenCopy.children = [duplicateEvent];
      expect(goldenCopy.toString(), isNot(equals(goldenUiString())));

      goldenCopy.maybeRemoveDuplicate();
      expect(goldenCopy.toString(), equals(goldenUiString()));
    });

    test('removeChild', () {
      final goldenCopy = goldenUiTimelineEvent.deepCopy();

      // VSYNC
      //  Animator::BeginFrame
      //   Framework Workload
      //    Engine::BeginFrame <-- [goldenEvent], [copyEvent]
      //     Frame <-- event we will remove
      final engineBeginFrameEvent =
          goldenCopy.children.first.children.first.children.first;
      expect(engineBeginFrameEvent.name, equals('Engine::BeginFrame'));

      // Ensure [engineBeginFrameEvent]'s only child is the Frame event.
      expect(engineBeginFrameEvent.children.length, equals(1));
      final frameEvent = engineBeginFrameEvent.children.first;
      expect(frameEvent.children.length, equals(7));

      // Remove the Frame event from [engineBeginFrameEvent]'s chiengineBeginFrameEventldren.
      engineBeginFrameEvent.removeChild(frameEvent);

      // Now [frameEvent]'s children are [engineBeginFrameEvent]'s children.
      expect(engineBeginFrameEvent.children.length, equals(7));
      expect(
        collectionEquals(engineBeginFrameEvent.children, frameEvent.children),
        isTrue,
      );
    });

    test('addChild', () {
      final engineBeginFrame = testTimelineEvent(_engineBeginFrameJson);
      expect(engineBeginFrame.children.isEmpty, isTrue);

      // Add child [animate] to a leaf [engineBeginFrame].
      final animate = testTimelineEvent(_animateJson)
        ..time.end = const Duration(microseconds: 118039650871);
      engineBeginFrame.addChild(animate);
      expect(engineBeginFrame.children.length, equals(1));
      expect(engineBeginFrame.children.first.name, equals(animateEvent.name));

      // Add child [layout] where child is sibling of existing children
      // [animate].
      final layout = testTimelineEvent(_layoutJson)
        ..time.end = const Duration(microseconds: 118039651087);
      engineBeginFrame.addChild(layout);
      expect(engineBeginFrame.children.length, equals(2));
      expect(engineBeginFrame.children.last.name, equals(layoutEvent.name));

      // Add child [build] where existing child [layout] is parent of child.
      final build = testTimelineEvent(_buildJson)
        ..time.end = const Duration(microseconds: 118039651017);
      engineBeginFrame.addChild(build);
      expect(engineBeginFrame.children.length, equals(2));
      expect(layout.children.length, equals(1));
      expect(layout.children.first.name, equals(buildEvent.name));

      // Add child [frame] child is parent of existing children [animate] and
      // [layout].
      final frame = testTimelineEvent(_frameJson)
        ..time.end = const Duration(microseconds: 118039652334);
      engineBeginFrame.addChild(frame);
      expect(engineBeginFrame.children.length, equals(1));
      expect(engineBeginFrame.children.first.name, equals(frameEvent.name));
      expect(frame.children.length, equals(2));
      expect(frame.children.first.name, equals(animateEvent.name));
      expect(frame.children.last.name, equals(layoutEvent.name));
    });
  });

  test('recordTrace', () {
    timelineTraceEvents.clear();
    goldenUiTimelineEvent.recordTrace();
    expect(
      timelineTraceEvents,
      equals([
        _vsyncJson,
        _animatorBeginFrameJson,
        _frameworkWorkloadJson,
        _engineBeginFrameJson,
        _frameJson,
        _animateJson,
        _layoutJson,
        _buildJson,
        _compositingBitsJson,
        _paintJson,
        _compositingJson,
        _semanticsJson,
        _finalizeTreeJson,
        _endEngineBeginFrameJson,
        _endFrameworkWorkloadJson,
        _endAnimatorBeginFrameJson,
        _endVsyncJson,
      ]),
    );

    timelineTraceEvents.clear();
    goldenGpuTimelineEvent.recordTrace();
    expect(
      timelineTraceEvents,
      equals([
        _gpuRasterizerDrawJson,
        _pipelineConsumeJson,
        _endPipelineConsumeJson,
        _endGpuRasterizerDrawJson,
      ]),
    );
  });
}

Future<void> delayForEventProcessing() async {
  await Future.delayed(const Duration(milliseconds: 1500));
}

const uiThreadId = 1;
const gpuThreadId = 2;
const unknownThreadId = 3;

final frameStartEvent = testTraceEvent({
  'name': 'PipelineItem',
  'cat': 'Embedder',
  'tid': uiThreadId,
  'pid': 94955,
  'ts': 118039650806,
  'ph': 's',
  'id': 'f1',
  'args': {}
});

final frameEndEvent = testTraceEvent({
  'name': 'PipelineItem',
  'cat': 'Embedder',
  'tid': gpuThreadId,
  'pid': 94955,
  'ts': 118039679872,
  'ph': 'f',
  'bp': 'e',
  'id': 'f1',
  'args': {}
});

// Mark: UI golden data.
// None of the following data should be modified. If you have a need to modify
// any of the below events for a test, make a copy and modify the copy.
final TimelineEvent vsyncEvent = testTimelineEvent(_vsyncJson)
  ..time.end = const Duration(microseconds: 118039652422)
  ..type = TimelineEventType.ui;

final TimelineEvent animatorBeginFrameEvent =
    testTimelineEvent(_animatorBeginFrameJson)
      ..time.end = const Duration(microseconds: 118039652421)
      ..type = TimelineEventType.ui;

final TimelineEvent frameworkWorkloadEvent =
    testTimelineEvent(_frameworkWorkloadJson)
      ..time.end = const Duration(microseconds: 118039652412)
      ..type = TimelineEventType.ui;

final TimelineEvent engineBeginFrameEvent =
    testTimelineEvent(_engineBeginFrameJson)
      ..time.end = const Duration(microseconds: 118039652411)
      ..type = TimelineEventType.ui;

final TimelineEvent frameEvent = testTimelineEvent(_frameJson)
  ..time.end = const Duration(microseconds: 118039652334)
  ..type = TimelineEventType.ui;

final TimelineEvent animateEvent = testTimelineEvent(_animateJson)
  ..time.end = const Duration(microseconds: 118039650871)
  ..type = TimelineEventType.ui;

final TimelineEvent layoutEvent = testTimelineEvent(_layoutJson)
  ..time.end = const Duration(microseconds: 118039651087)
  ..type = TimelineEventType.ui;

final TimelineEvent buildEvent = testTimelineEvent(_buildJson)
  ..time.end = const Duration(microseconds: 118039651017)
  ..type = TimelineEventType.ui;

final TimelineEvent compositingBitsEvent =
    testTimelineEvent(_compositingBitsJson)
      ..time.end = const Duration(microseconds: 118039651090)
      ..type = TimelineEventType.ui;

final TimelineEvent paintEvent = testTimelineEvent(_paintJson)
  ..time.end = const Duration(microseconds: 118039651165)
  ..type = TimelineEventType.ui;

final TimelineEvent compositingEvent = testTimelineEvent(_compositingJson)
  ..time.end = const Duration(microseconds: 118039651460)
  ..type = TimelineEventType.ui;

final TimelineEvent semanticsEvent = testTimelineEvent(_semanticsJson)
  ..time.end = const Duration(microseconds: 118039652210)
  ..type = TimelineEventType.ui;

final TimelineEvent finalizeTreeEvent = testTimelineEvent(_finalizeTreeJson)
  ..time.end = const Duration(microseconds: 118039652308)
  ..type = TimelineEventType.ui;

final goldenUiTimelineEvent = vsyncEvent
  ..children = [
    animatorBeginFrameEvent
      ..parent = vsyncEvent
      ..children = [
        frameworkWorkloadEvent
          ..parent = animatorBeginFrameEvent
          ..children = [
            engineBeginFrameEvent
              ..parent = frameworkWorkloadEvent
              ..children = [
                frameEvent
                  ..parent = engineBeginFrameEvent
                  ..children = [
                    animateEvent..parent = frameEvent,
                    layoutEvent
                      ..parent = frameEvent
                      ..children = [buildEvent..parent = layoutEvent],
                    compositingBitsEvent..parent = frameEvent,
                    paintEvent..parent = frameEvent,
                    compositingEvent..parent = frameEvent,
                    semanticsEvent..parent = frameEvent,
                    finalizeTreeEvent..parent = frameEvent,
                  ]
              ]
              ..traceEvents
                  .add(testTraceEventWrapper(_endEngineBeginFrameJson)),
          ]
          ..traceEvents.add(testTraceEventWrapper(_endFrameworkWorkloadJson)),
      ]
      ..traceEvents.add(testTraceEventWrapper(_endAnimatorBeginFrameJson)),
  ]
  ..traceEvents.add(testTraceEventWrapper(_endVsyncJson));

String goldenUiString() => goldenUiTimelineEvent.toString();

final List<TraceEvent> goldenUiTraceEvents = [
  testTraceEvent(_vsyncJson),
  testTraceEvent(_animatorBeginFrameJson),
  testTraceEvent(_frameworkWorkloadJson),
  testTraceEvent(_engineBeginFrameJson),
  testTraceEvent(_animateJson),
  testTraceEvent(_buildJson),
  testTraceEvent(_layoutJson),
  testTraceEvent(_compositingBitsJson),
  testTraceEvent(_paintJson),
  testTraceEvent(_compositingJson),
  testTraceEvent(_semanticsJson),
  testTraceEvent(_finalizeTreeJson),
  testTraceEvent(_frameJson),
  testTraceEvent(_endEngineBeginFrameJson),
  testTraceEvent(_endFrameworkWorkloadJson),
  testTraceEvent(_endAnimatorBeginFrameJson),
  testTraceEvent(_endVsyncJson),
];

const Map<String, dynamic> _vsyncJson = {
  'name': 'VSYNC',
  'cat': 'Embedder',
  'tid': uiThreadId,
  'pid': 94955,
  'ts': 118039650802,
  'ph': 'B',
  'args': {}
};

const Map<String, dynamic> _animatorBeginFrameJson = {
  'name': 'Animator::BeginFrame',
  'cat': 'Embedder',
  'tid': uiThreadId,
  'pid': 94955,
  'ts': 118039650803,
  'ph': 'B',
  'args': {}
};

const Map<String, dynamic> _frameworkWorkloadJson = {
  'name': 'Framework Workload',
  'cat': 'Embedder',
  'tid': uiThreadId,
  'pid': 94955,
  'ts': 118039650807,
  'ph': 'B',
  'args': {'mode': 'basic', 'frame': 'odd'}
};

const Map<String, dynamic> _engineBeginFrameJson = {
  'name': 'Engine::BeginFrame',
  'cat': 'Embedder',
  'tid': uiThreadId,
  'pid': 94955,
  'ts': 118039650809,
  'ph': 'B',
  'args': {}
};

const Map<String, dynamic> _animateJson = {
  'name': 'Animate',
  'cat': 'Dart',
  'tid': uiThreadId,
  'pid': 94955,
  'ts': 118039650838,
  'ph': 'X',
  'dur': 33,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> _buildJson = {
  'name': 'Build',
  'cat': 'Dart',
  'tid': uiThreadId,
  'pid': 94955,
  'ts': 118039650984,
  'ph': 'X',
  'dur': 33,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> _layoutJson = {
  'name': 'Layout',
  'cat': 'Dart',
  'tid': uiThreadId,
  'pid': 94955,
  'ts': 118039650876,
  'ph': 'X',
  'dur': 211,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> _compositingBitsJson = {
  'name': 'Compositing bits',
  'cat': 'Dart',
  'tid': uiThreadId,
  'pid': 94955,
  'ts': 118039651088,
  'ph': 'X',
  'dur': 2,
  'args': {'isolateNumber': '993728060'}
};

const Map<String, dynamic> _paintJson = {
  'name': 'Paint',
  'cat': 'Dart',
  'tid': uiThreadId,
  'pid': 94955,
  'ts': 118039651091,
  'ph': 'X',
  'dur': 74,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> _compositingJson = {
  'name': 'Compositing',
  'cat': 'Dart',
  'tid': uiThreadId,
  'pid': 94955,
  'ts': 118039651166,
  'ph': 'X',
  'dur': 294,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> _semanticsJson = {
  'name': 'Semantics',
  'cat': 'Dart',
  'tid': uiThreadId,
  'pid': 94955,
  'ts': 118039651462,
  'ph': 'X',
  'dur': 748,
  'args': {'isolateNumber': '993728060'}
};

const Map<String, dynamic> _finalizeTreeJson = {
  'name': 'Finalize tree',
  'cat': 'Dart',
  'tid': uiThreadId,
  'pid': 94955,
  'ts': 118039652219,
  'ph': 'X',
  'dur': 89,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> _frameJson = {
  'name': 'Frame',
  'cat': 'Dart',
  'tid': uiThreadId,
  'pid': 94955,
  'ts': 118039650834,
  'ph': 'X',
  'dur': 1500,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> _endVsyncJson = {
  'name': 'VSYNC',
  'cat': 'Embedder',
  'tid': uiThreadId,
  'pid': 94955,
  'ts': 118039652422,
  'ph': 'E',
  'args': {}
};

const Map<String, dynamic> _endAnimatorBeginFrameJson = {
  'name': 'Animator::BeginFrame',
  'cat': 'Embedder',
  'tid': uiThreadId,
  'pid': 94955,
  'ts': 118039652421,
  'ph': 'E',
  'args': {}
};

const Map<String, dynamic> _endFrameworkWorkloadJson = {
  'name': 'Framework Workload',
  'cat': 'Embedder',
  'tid': uiThreadId,
  'pid': 94955,
  'ts': 118039652412,
  'ph': 'E',
  'args': {}
};

const Map<String, dynamic> _endEngineBeginFrameJson = {
  'name': 'Engine::BeginFrame',
  'cat': 'Embedder',
  'tid': uiThreadId,
  'pid': 94955,
  'ts': 118039652411,
  'ph': 'E',
  'args': {}
};

// Mark: GPU golden data. This data is abbreviated in comparison to the UI
// golden data. We do not need both data sets to be complete for testing.
// None of the following data should be modified. If you have a need to modify
// any of the below events for a test, make a copy and modify the copy.
final TimelineEvent gpuRasterizerDrawEvent =
    testTimelineEvent(_gpuRasterizerDrawJson)
      ..time.end = const Duration(microseconds: 118039679873)
      ..type = TimelineEventType.gpu;

final TimelineEvent pipelineConsumeEvent =
    testTimelineEvent(_pipelineConsumeJson)
      ..time.end = const Duration(microseconds: 118039679870)
      ..type = TimelineEventType.gpu;

final goldenGpuTimelineEvent = gpuRasterizerDrawEvent
  ..children = [
    pipelineConsumeEvent
      ..traceEvents.add(testTraceEventWrapper(_endPipelineConsumeJson))
  ]
  ..traceEvents.add(testTraceEventWrapper(_endGpuRasterizerDrawJson));

String goldenGpuString() => goldenGpuTimelineEvent.toString();

final List<TraceEvent> goldenGpuTraceEvents = [
  testTraceEvent(_gpuRasterizerDrawJson),
  testTraceEvent(_pipelineConsumeJson),
  testTraceEvent(_endPipelineConsumeJson),
  testTraceEvent(_endGpuRasterizerDrawJson),
];

const Map<String, dynamic> _gpuRasterizerDrawJson = {
  'name': 'GPURasterizer::Draw',
  'cat': 'Embedder',
  'tid': gpuThreadId,
  'pid': 94955,
  'ts': 118039651469,
  'ph': 'B',
  'args': {}
};

const Map<String, dynamic> _pipelineConsumeJson = {
  'name': 'PipelineConsume',
  'cat': 'Embedder',
  'tid': gpuThreadId,
  'pid': 94955,
  'ts': 118039651470,
  'ph': 'B',
  'args': {}
};
const Map<String, dynamic> _endPipelineConsumeJson = {
  'name': 'PipelineConsume',
  'cat': 'Embedder',
  'tid': gpuThreadId,
  'pid': 94955,
  'ts': 118039679870,
  'ph': 'E',
  'args': {}
};

const Map<String, dynamic> _endGpuRasterizerDrawJson = {
  'name': 'GPURasterizer::Draw',
  'cat': 'Embedder',
  'tid': gpuThreadId,
  'pid': 94955,
  'ts': 118039679873,
  'ph': 'E',
  'args': {}
};
