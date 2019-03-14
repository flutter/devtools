// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

//import 'dart:async';
import 'dart:convert';

import 'package:devtools/src/timeline/timeline_protocol.dart';
import 'package:devtools/src/utils.dart';
import 'package:test/test.dart';

void main() {
  final originalGoldenCpuEvent = goldenCpuTimelineEvent.deepCopy();
  final originalGoldenGpuEvent = goldenGpuTimelineEvent.deepCopy();
  final originalGoldenCpuTraceEvents = List.of(goldenCpuTraceEvents);
  final originalGoldenGpuTraceEvents = List.of(goldenGpuTraceEvents);

  setUp(() {
    // If any of these expect statements fail, a golden was modified while the
    // tests were running. Do not modify the goldens. Instead, make a copy and
    // modify the copy.
    expect(goldenCpuString() == originalGoldenCpuEvent.toString(), isTrue);
    expect(goldenGpuString() == originalGoldenGpuEvent.toString(), isTrue);
    expect(
      collectionEquals<List<TraceEvent>>(
        goldenCpuTraceEvents,
        originalGoldenCpuTraceEvents,
      ),
      isTrue,
    );
    expect(
      collectionEquals<List<TraceEvent>>(
        goldenGpuTraceEvents,
        originalGoldenGpuTraceEvents,
      ),
      isTrue,
    );
  });

  group('TimelineData', () {
    TimelineData timelineData;

    setUp(() {
      timelineData = TimelineData(
        cpuThreadId: cpuThreadId,
        gpuThreadId: gpuThreadId,
      );
    });

    test('infers correct trace event type', () {
      final cpuEvent = goldenCpuTraceEvents.first;
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

      expect(cpuEvent.type, equals(TimelineEventType.unknown));
      expect(gpuEvent.type, equals(TimelineEventType.unknown));
      expect(unknownEvent.type, equals(TimelineEventType.unknown));
      timelineData.processTraceEvent(cpuEvent);
      timelineData.processTraceEvent(gpuEvent);
      timelineData.processTraceEvent(unknownEvent);
      expect(cpuEvent.type, equals(TimelineEventType.cpu));
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
      goldenCpuTraceEvents.forEach(timelineData.processTraceEvent);

      await delayForEventProcessing();

      expect(timelineData.pendingEvents.length, equals(1));
      final processedCpuEvent = timelineData.pendingEvents.first;
      expect(processedCpuEvent.toString(), equals(goldenCpuString()));
    });

    test('event occurs within frame boundaries', () {
      const frameStartTime = 2000;
      const frameEndTime = 8000;
      final frame = TimelineFrame('frameId')
        ..startTime = frameStartTime
        ..endTime = frameEndTime;

      final event = goldenCpuTimelineEvent.deepCopy()
        ..startTime = frameStartTime
        ..endTime = 5000;

      // Event fits within frame timestamps.
      expect(timelineData.eventOccursWithinFrameBounds(event, frame), isTrue);

      // Event fits within epsilon of frame start.
      event.startTime = frameStartTime - traceEventEpsilon.inMicroseconds;
      expect(timelineData.eventOccursWithinFrameBounds(event, frame), isTrue);

      // Event does not fit within epsilon of frame start.
      event.startTime = frameStartTime - traceEventEpsilon.inMicroseconds - 1;
      expect(timelineData.eventOccursWithinFrameBounds(event, frame), isFalse);

      // Event with small duration uses smaller epsilon.
      event.startTime = frameStartTime - 100;
      event.endTime = frameStartTime + 100;
      expect(timelineData.eventOccursWithinFrameBounds(event, frame), isTrue);

      event.startTime = frameStartTime - 101;
      event.endTime = frameStartTime + 100;
      expect(timelineData.eventOccursWithinFrameBounds(event, frame), isFalse);

      // Event fits within epsilon of frame end.
      event.endTime = frameEndTime + traceEventEpsilon.inMicroseconds;
      expect(timelineData.eventOccursWithinFrameBounds(event, frame), isTrue);

      // Event does not fit within epsilon of frame end.
      event.endTime = frameEndTime + traceEventEpsilon.inMicroseconds + 1;
      expect(timelineData.eventOccursWithinFrameBounds(event, frame), isFalse);

      // Satisfies CPU / GPU order.
      final cpuEvent = event
        ..startTime = 5000
        ..endTime = 6000;
      final gpuEvent = goldenGpuTimelineEvent.deepCopy()
        ..startTime = 4000
        ..endTime = 8000;

      expect(
          timelineData.eventOccursWithinFrameBounds(cpuEvent, frame), isTrue);
      expect(
          timelineData.eventOccursWithinFrameBounds(gpuEvent, frame), isTrue);

      frame.eventFlows[TimelineEventType.cpu.index] = cpuEvent;
      expect(
          timelineData.eventOccursWithinFrameBounds(gpuEvent, frame), isFalse);

      frame.eventFlows[TimelineEventType.cpu.index] = null;
      frame.eventFlows[TimelineEventType.gpu.index] = gpuEvent;
      expect(
          timelineData.eventOccursWithinFrameBounds(cpuEvent, frame), isFalse);
    });

    test('frame completed', () async {
      expect(timelineData.pendingEvents, isEmpty);
      goldenCpuTraceEvents.forEach(timelineData.processTraceEvent);
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
      expect(frame.cpuEventFlow.toString(), equals(goldenCpuString()));
      expect(frame.gpuEventFlow.toString(), equals(goldenGpuString()));
      expect(frame.addedToTimeline, isTrue);
    });

    test('handles out of order timestamps', () async {
      final List<TraceEvent> traceEvents = List.of(goldenCpuTraceEvents);
      traceEvents.reversed.forEach(timelineData.processTraceEvent);
      await delayForEventProcessing();
      expect(timelineData.pendingEvents.length, equals(1));
      expect(timelineData.pendingEvents.first.toString(),
          equals(goldenCpuString()));
    });

    test('handles trace event duplicates', () async {
      // Duplicate duration begin event.
      // VSYNC
      //  Animator::BeginFrame
      //   Animator::BeginFrame
      //     ...
      //  Animator::BeginFrame
      // VSYNC
      List<TraceEvent> traceEvents = List.of(goldenCpuTraceEvents);
      traceEvents.insert(1, goldenCpuTraceEvents[1]);

      traceEvents.forEach(timelineData.processTraceEvent);
      await delayForEventProcessing();
      expect(timelineData.pendingEvents.length, equals(1));
      expect(timelineData.pendingEvents.first.toString(),
          equals(goldenCpuString()));

      timelineData.pendingEvents.clear();

      // Duplicate duration end event.
      // VSYNC
      //  Animator::BeginFrame
      //     ...
      //   Animator::BeginFrame
      //  Animator::BeginFrame
      // VSYNC
      traceEvents = List.of(goldenCpuTraceEvents);
      traceEvents.insert(goldenCpuTraceEvents.length - 2,
          goldenCpuTraceEvents[goldenCpuTraceEvents.length - 2]);

      traceEvents.forEach(timelineData.processTraceEvent);
      await delayForEventProcessing();
      expect(timelineData.pendingEvents.length, equals(1));
      expect(timelineData.pendingEvents.first.toString(),
          equals(goldenCpuString()));

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
        'tid': cpuThreadId,
        'pid': 94955,
        'ts': 118039650802,
        'ph': 'B',
        'args': {}
      });
      final animatorBeginFrameEvent = testTraceEvent({
        'name': 'Animator::BeginFrame',
        'cat': 'Embedder',
        'tid': cpuThreadId,
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
      traceEvents.addAll(
          goldenCpuTraceEvents.getRange(2, goldenCpuTraceEvents.length));
      traceEvents.insert(2, goldenCpuTraceEvents[0]);
      traceEvents.insert(3, goldenCpuTraceEvents[1]);
      traceEvents.forEach(timelineData.processTraceEvent);
      await delayForEventProcessing();
      expect(timelineData.pendingEvents.length, equals(0));
      expect(
          timelineData.currentEventNodes[TimelineEventType.cpu.index], isNull);
    });
  });

  group('TimelineEvent', () {
    test('get depth', () {
      expect(goldenCpuTimelineEvent.depth, equals(7));
    });

    test('getRoot', () {
      expect(goldenCpuTimelineEvent.getRoot(), equals(vsyncEvent));
      expect(buildEvent.getRoot(), equals(vsyncEvent));
    });

    test('containsChildWithCondition', () {
      expect(
        goldenCpuTimelineEvent
            .containsChildWithCondition((TimelineEvent event) {
          return event.name == 'Animate';
        }),
        isTrue,
      );
      expect(
        goldenCpuTimelineEvent
            .containsChildWithCondition((TimelineEvent event) {
          return event.beginTraceEventJson == animateEvent.beginTraceEventJson;
        }),
        isTrue,
      );
      expect(
        goldenCpuTimelineEvent
            .containsChildWithCondition((TimelineEvent event) {
          return event.name == 'FakeEventName';
        }),
        isFalse,
      );
    });

    test('maybeRemoveDuplicate', () {
      final goldenCopy = goldenCpuTimelineEvent.deepCopy();

      // Event with no duplicates should be unchanged.
      goldenCopy.maybeRemoveDuplicate();
      expect(goldenCopy.toString(), equals(goldenCpuString()));

      // Add a duplicate event in [goldenCopy]'s event tree.
      final duplicateEvent = goldenCopy.deepCopy();
      duplicateEvent.parent = goldenCopy;
      duplicateEvent.children = goldenCopy.children;
      goldenCopy.children = [duplicateEvent];
      expect(goldenCopy.toString(), isNot(equals(goldenCpuString())));

      goldenCopy.maybeRemoveDuplicate();
      expect(goldenCopy.toString(), equals(goldenCpuString()));
    });

    test('removeChild', () {
      final goldenCopy = goldenCpuTimelineEvent.deepCopy();

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
        collectionEquals<List<TimelineEvent>>(
          engineBeginFrameEvent.children,
          frameEvent.children,
        ),
        isTrue,
      );
    });

    test('addChild', () {
      final engineBeginFrame = testTimelineEvent(_engineBeginFrameJson);
      expect(engineBeginFrame.children.isEmpty, isTrue);

      // Add child [animate] to a leaf [engineBeginFrame].
      final animate = testTimelineEvent(_animateJson)..endTime = 118039650871;
      engineBeginFrame.addChild(animate);
      expect(engineBeginFrame.children.length, equals(1));
      expect(engineBeginFrame.children.first.name, equals(animateEvent.name));

      // Add child [layout] where child is sibling of existing children
      // [animate].
      final layout = testTimelineEvent(_layoutJson)..endTime = 118039651087;
      engineBeginFrame.addChild(layout);
      expect(engineBeginFrame.children.length, equals(2));
      expect(engineBeginFrame.children.last.name, equals(layoutEvent.name));

      // Add child [build] where existing child [layout] is parent of child.
      final build = testTimelineEvent(_buildJson)..endTime = 118039651017;
      engineBeginFrame.addChild(build);
      expect(engineBeginFrame.children.length, equals(2));
      expect(layout.children.length, equals(1));
      expect(layout.children.first.name, equals(buildEvent.name));

      // Add child [frame] child is parent of existing children [animate] and
      // [layout].
      final frame = testTimelineEvent(_frameJson)..endTime = 118039652334;
      engineBeginFrame.addChild(frame);
      expect(engineBeginFrame.children.length, equals(1));
      expect(engineBeginFrame.children.first.name, equals(frameEvent.name));
      expect(frame.children.length, equals(2));
      expect(frame.children.first.name, equals(animateEvent.name));
      expect(frame.children.last.name, equals(layoutEvent.name));
    });
  });
}

Future<void> delayForEventProcessing() async {
  await Future.delayed(Duration(milliseconds: 1500));
}

TimelineEvent testTimelineEvent(Map<String, dynamic> json) =>
    TimelineEvent(testTraceEventWrapper(json));

TraceEvent testTraceEvent(Map<String, dynamic> json) =>
    TraceEvent(jsonDecode(jsonEncode(json)));

int _testTimeReceived = 0;

TraceEventWrapper testTraceEventWrapper(Map<String, dynamic> json) {
  return TraceEventWrapper(testTraceEvent(json), _testTimeReceived++);
}

const cpuThreadId = 1;
const gpuThreadId = 2;
const unknownThreadId = 3;

final frameStartEvent = testTraceEvent({
  'name': 'PipelineItem',
  'cat': 'Embedder',
  'tid': cpuThreadId,
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

// Mark: CPU golden data.
// None of the following data should be modified. If you have a need to modify
// any of the below events for a test, make a copy and modify the copy.
final TimelineEvent vsyncEvent = testTimelineEvent(_vsyncJson)
  ..endTime = 118039652422
  ..type = TimelineEventType.cpu;

final TimelineEvent animatorBeginFrameEvent =
    testTimelineEvent(_animatorBeginFrameJson)
      ..endTime = 118039652421
      ..type = TimelineEventType.cpu;

final TimelineEvent frameworkWorkloadEvent =
    testTimelineEvent(_frameworkWorkloadJson)
      ..endTime = 118039652412
      ..type = TimelineEventType.cpu;

final TimelineEvent engineBeginFrameEvent =
    testTimelineEvent(_engineBeginFrameJson)
      ..endTime = 118039652411
      ..type = TimelineEventType.cpu;

final TimelineEvent frameEvent = testTimelineEvent(_frameJson)
  ..endTime = 118039652334
  ..type = TimelineEventType.cpu;

final TimelineEvent animateEvent = testTimelineEvent(_animateJson)
  ..endTime = 118039650871
  ..type = TimelineEventType.cpu;

final TimelineEvent layoutEvent = testTimelineEvent(_layoutJson)
  ..endTime = 118039651087
  ..type = TimelineEventType.cpu;

final TimelineEvent buildEvent = testTimelineEvent(_buildJson)
  ..endTime = 118039651017
  ..type = TimelineEventType.cpu;

final TimelineEvent compositingBitsEvent =
    testTimelineEvent(_compositingBitsJson)
      ..endTime = 118039651090
      ..type = TimelineEventType.cpu;

final TimelineEvent paintEvent = testTimelineEvent(_paintJson)
  ..endTime = 118039651165
  ..type = TimelineEventType.cpu;

final TimelineEvent compositingEvent = testTimelineEvent(_compositingJson)
  ..endTime = 118039651460
  ..type = TimelineEventType.cpu;

final TimelineEvent semanticsEvent = testTimelineEvent(_semanticsJson)
  ..endTime = 118039652210
  ..type = TimelineEventType.cpu;

final TimelineEvent finalizeTreeEvent = testTimelineEvent(_finalizeTreeJson)
  ..endTime = 118039652308
  ..type = TimelineEventType.cpu;

final goldenCpuTimelineEvent = vsyncEvent
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

String goldenCpuString() => goldenCpuTimelineEvent.toString();

final List<TraceEvent> goldenCpuTraceEvents = [
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
  'tid': cpuThreadId,
  'pid': 94955,
  'ts': 118039650802,
  'ph': 'B',
  'args': {}
};

const Map<String, dynamic> _animatorBeginFrameJson = {
  'name': 'Animator::BeginFrame',
  'cat': 'Embedder',
  'tid': cpuThreadId,
  'pid': 94955,
  'ts': 118039650803,
  'ph': 'B',
  'args': {}
};

const Map<String, dynamic> _frameworkWorkloadJson = {
  'name': 'Framework Workload',
  'cat': 'Embedder',
  'tid': cpuThreadId,
  'pid': 94955,
  'ts': 118039650807,
  'ph': 'B',
  'args': {'mode': 'basic', 'frame': 'odd'}
};

const Map<String, dynamic> _engineBeginFrameJson = {
  'name': 'Engine::BeginFrame',
  'cat': 'Embedder',
  'tid': cpuThreadId,
  'pid': 94955,
  'ts': 118039650809,
  'ph': 'B',
  'args': {}
};

const Map<String, dynamic> _animateJson = {
  'name': 'Animate',
  'cat': 'Dart',
  'tid': cpuThreadId,
  'pid': 94955,
  'ts': 118039650838,
  'ph': 'X',
  'dur': 33,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> _buildJson = {
  'name': 'Build',
  'cat': 'Dart',
  'tid': cpuThreadId,
  'pid': 94955,
  'ts': 118039650984,
  'ph': 'X',
  'dur': 33,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> _layoutJson = {
  'name': 'Layout',
  'cat': 'Dart',
  'tid': cpuThreadId,
  'pid': 94955,
  'ts': 118039650876,
  'ph': 'X',
  'dur': 211,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> _compositingBitsJson = {
  'name': 'Compositing bits',
  'cat': 'Dart',
  'tid': cpuThreadId,
  'pid': 94955,
  'ts': 118039651088,
  'ph': 'X',
  'dur': 2,
  'args': {'isolateNumber': '993728060'}
};

const Map<String, dynamic> _paintJson = {
  'name': 'Paint',
  'cat': 'Dart',
  'tid': cpuThreadId,
  'pid': 94955,
  'ts': 118039651091,
  'ph': 'X',
  'dur': 74,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> _compositingJson = {
  'name': 'Compositing',
  'cat': 'Dart',
  'tid': cpuThreadId,
  'pid': 94955,
  'ts': 118039651166,
  'ph': 'X',
  'dur': 294,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> _semanticsJson = {
  'name': 'Semantics',
  'cat': 'Dart',
  'tid': cpuThreadId,
  'pid': 94955,
  'ts': 118039651462,
  'ph': 'X',
  'dur': 748,
  'args': {'isolateNumber': '993728060'}
};

const Map<String, dynamic> _finalizeTreeJson = {
  'name': 'Finalize tree',
  'cat': 'Dart',
  'tid': cpuThreadId,
  'pid': 94955,
  'ts': 118039652219,
  'ph': 'X',
  'dur': 89,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> _frameJson = {
  'name': 'Frame',
  'cat': 'Dart',
  'tid': cpuThreadId,
  'pid': 94955,
  'ts': 118039650834,
  'ph': 'X',
  'dur': 1500,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> _endVsyncJson = {
  'name': 'VSYNC',
  'cat': 'Embedder',
  'tid': cpuThreadId,
  'pid': 94955,
  'ts': 118039652422,
  'ph': 'E',
  'args': {}
};

const Map<String, dynamic> _endAnimatorBeginFrameJson = {
  'name': 'Animator::BeginFrame',
  'cat': 'Embedder',
  'tid': cpuThreadId,
  'pid': 94955,
  'ts': 118039652421,
  'ph': 'E',
  'args': {}
};

const Map<String, dynamic> _endFrameworkWorkloadJson = {
  'name': 'Framework Workload',
  'cat': 'Embedder',
  'tid': cpuThreadId,
  'pid': 94955,
  'ts': 118039652412,
  'ph': 'E',
  'args': {}
};

const Map<String, dynamic> _endEngineBeginFrameJson = {
  'name': 'Engine::BeginFrame',
  'cat': 'Embedder',
  'tid': cpuThreadId,
  'pid': 94955,
  'ts': 118039652411,
  'ph': 'E',
  'args': {}
};

// Mark: GPU golden data. This data is abbreviated in comparison to the CPU
// golden data. We do not need both data sets to be complete for testing.
// None of the following data should be modified. If you have a need to modify
// any of the below events for a test, make a copy and modify the copy.
final TimelineEvent gpuRasterizerDrawEvent =
    testTimelineEvent(_gpuRasterizerDrawJson)
      ..endTime = 118039679873
      ..type = TimelineEventType.gpu;

final TimelineEvent pipelineConsumeEvent =
    testTimelineEvent(_pipelineConsumeJson)
      ..endTime = 118039679870
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
