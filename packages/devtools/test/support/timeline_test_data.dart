// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:devtools/src/timeline/timeline_controller.dart'
    show timelineScreenId;
import 'package:devtools/src/timeline/timeline_model.dart';

import 'cpu_profile_test_data.dart';
import 'test_utils.dart';

const testUiThreadId = 1;
const testGpuThreadId = 2;
const testUnknownThreadId = 3;

final frameStartEvent = testTraceEvent({
  'name': 'PipelineItem',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039650806,
  'ph': 's',
  'id': 'f1',
  'args': {}
});

final frameEndEvent = testTraceEvent({
  'name': 'PipelineItem',
  'cat': 'Embedder',
  'tid': testGpuThreadId,
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
final TimelineEvent vsyncEvent = testTimelineEvent(vsyncJson)
  ..time.end = const Duration(microseconds: 118039652422)
  ..type = TimelineEventType.ui;

final TimelineEvent animatorBeginFrameEvent =
    testTimelineEvent(animatorBeginFrameJson)
      ..time.end = const Duration(microseconds: 118039652421)
      ..type = TimelineEventType.ui;

final TimelineEvent frameworkWorkloadEvent =
    testTimelineEvent(frameworkWorkloadJson)
      ..time.end = const Duration(microseconds: 118039652412)
      ..type = TimelineEventType.ui;

final TimelineEvent engineBeginFrameEvent =
    testTimelineEvent(engineBeginFrameJson)
      ..time.end = const Duration(microseconds: 118039652411)
      ..type = TimelineEventType.ui;

final TimelineEvent frameEvent = testTimelineEvent(frameJson)
  ..time.end = const Duration(microseconds: 118039652334)
  ..type = TimelineEventType.ui;

final TimelineEvent animateEvent = testTimelineEvent(animateJson)
  ..time.end = const Duration(microseconds: 118039650871)
  ..type = TimelineEventType.ui;

final TimelineEvent layoutEvent = testTimelineEvent(layoutJson)
  ..time.end = const Duration(microseconds: 118039651087)
  ..type = TimelineEventType.ui;

final TimelineEvent buildEvent = testTimelineEvent(buildJson)
  ..time.end = const Duration(microseconds: 118039651017)
  ..type = TimelineEventType.ui;

final TimelineEvent compositingBitsEvent =
    testTimelineEvent(compositingBitsJson)
      ..time.end = const Duration(microseconds: 118039651090)
      ..type = TimelineEventType.ui;

final TimelineEvent paintEvent = testTimelineEvent(paintJson)
  ..time.end = const Duration(microseconds: 118039651165)
  ..type = TimelineEventType.ui;

final TimelineEvent compositingEvent = testTimelineEvent(compositingJson)
  ..time.end = const Duration(microseconds: 118039651460)
  ..type = TimelineEventType.ui;

final TimelineEvent semanticsEvent = testTimelineEvent(semanticsJson)
  ..time.end = const Duration(microseconds: 118039652210)
  ..type = TimelineEventType.ui;

final TimelineEvent finalizeTreeEvent = testTimelineEvent(finalizeTreeJson)
  ..time.end = const Duration(microseconds: 118039652308)
  ..type = TimelineEventType.ui;

final goldenUiTimelineEvent = vsyncEvent
  ..children.addAll([
    animatorBeginFrameEvent
      ..parent = vsyncEvent
      ..children.addAll([
        frameworkWorkloadEvent
          ..parent = animatorBeginFrameEvent
          ..children.addAll([
            engineBeginFrameEvent
              ..parent = frameworkWorkloadEvent
              ..children.addAll([
                frameEvent
                  ..parent = engineBeginFrameEvent
                  ..children.addAll([
                    animateEvent..parent = frameEvent,
                    layoutEvent
                      ..parent = frameEvent
                      ..children.add(buildEvent..parent = layoutEvent),
                    compositingBitsEvent..parent = frameEvent,
                    paintEvent..parent = frameEvent,
                    compositingEvent..parent = frameEvent,
                    semanticsEvent..parent = frameEvent,
                    finalizeTreeEvent..parent = frameEvent,
                  ])
              ])
              ..traceEvents.add(testTraceEventWrapper(endEngineBeginFrameJson)),
          ])
          ..traceEvents.add(testTraceEventWrapper(endFrameworkWorkloadJson)),
      ])
      ..traceEvents.add(testTraceEventWrapper(endAnimatorBeginFrameJson)),
  ])
  ..traceEvents.add(testTraceEventWrapper(endVsyncJson));

String goldenUiString() => goldenUiTimelineEvent.toString();

final List<TraceEvent> goldenUiTraceEvents = [
  testTraceEvent(vsyncJson),
  testTraceEvent(animatorBeginFrameJson),
  testTraceEvent(frameworkWorkloadJson),
  testTraceEvent(engineBeginFrameJson),
  testTraceEvent(animateJson),
  testTraceEvent(buildJson),
  testTraceEvent(layoutJson),
  testTraceEvent(compositingBitsJson),
  testTraceEvent(paintJson),
  testTraceEvent(compositingJson),
  testTraceEvent(semanticsJson),
  testTraceEvent(finalizeTreeJson),
  testTraceEvent(frameJson),
  testTraceEvent(endEngineBeginFrameJson),
  testTraceEvent(endFrameworkWorkloadJson),
  testTraceEvent(endAnimatorBeginFrameJson),
  testTraceEvent(endVsyncJson),
];

const Map<String, dynamic> vsyncJson = {
  'name': 'VSYNC',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039650802,
  'ph': 'B',
  'args': {}
};

const Map<String, dynamic> animatorBeginFrameJson = {
  'name': 'Animator::BeginFrame',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039650803,
  'ph': 'B',
  'args': {}
};

const Map<String, dynamic> frameworkWorkloadJson = {
  'name': 'Framework Workload',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039650807,
  'ph': 'B',
  'args': {'mode': 'basic', 'frame': 'odd'}
};

const Map<String, dynamic> engineBeginFrameJson = {
  'name': 'Engine::BeginFrame',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039650809,
  'ph': 'B',
  'args': {}
};

const Map<String, dynamic> animateJson = {
  'name': 'Animate',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039650838,
  'ph': 'X',
  'dur': 33,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> buildJson = {
  'name': 'Build',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039650984,
  'ph': 'X',
  'dur': 33,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> layoutJson = {
  'name': 'Layout',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039650876,
  'ph': 'X',
  'dur': 211,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> compositingBitsJson = {
  'name': 'Compositing bits',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039651088,
  'ph': 'X',
  'dur': 2,
  'args': {'isolateNumber': '993728060'}
};

const Map<String, dynamic> paintJson = {
  'name': 'Paint',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039651091,
  'ph': 'X',
  'dur': 74,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> compositingJson = {
  'name': 'Compositing',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039651166,
  'ph': 'X',
  'dur': 294,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> semanticsJson = {
  'name': 'Semantics',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039651462,
  'ph': 'X',
  'dur': 748,
  'args': {'isolateNumber': '993728060'}
};

const Map<String, dynamic> finalizeTreeJson = {
  'name': 'Finalize tree',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039652219,
  'ph': 'X',
  'dur': 89,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> frameJson = {
  'name': 'Frame',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039650834,
  'ph': 'X',
  'dur': 1500,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
};

const Map<String, dynamic> endVsyncJson = {
  'name': 'VSYNC',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039652422,
  'ph': 'E',
  'args': {}
};

const Map<String, dynamic> endAnimatorBeginFrameJson = {
  'name': 'Animator::BeginFrame',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039652421,
  'ph': 'E',
  'args': {}
};

const Map<String, dynamic> endFrameworkWorkloadJson = {
  'name': 'Framework Workload',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039652412,
  'ph': 'E',
  'args': {}
};

const Map<String, dynamic> endEngineBeginFrameJson = {
  'name': 'Engine::BeginFrame',
  'cat': 'Embedder',
  'tid': testUiThreadId,
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
    testTimelineEvent(gpuRasterizerDrawJson)
      ..time.end = const Duration(microseconds: 118039679873)
      ..type = TimelineEventType.gpu;

final TimelineEvent pipelineConsumeEvent =
    testTimelineEvent(pipelineConsumeJson)
      ..time.end = const Duration(microseconds: 118039679870)
      ..type = TimelineEventType.gpu;

final goldenGpuTimelineEvent = gpuRasterizerDrawEvent
  ..children.addAll([
    pipelineConsumeEvent
      ..traceEvents.add(testTraceEventWrapper(endPipelineConsumeJson))
  ])
  ..traceEvents.add(testTraceEventWrapper(endGpuRasterizerDrawJson));

String goldenGpuString() => goldenGpuTimelineEvent.toString();

final List<TraceEvent> goldenGpuTraceEvents = [
  testTraceEvent(gpuRasterizerDrawJson),
  testTraceEvent(pipelineConsumeJson),
  testTraceEvent(endPipelineConsumeJson),
  testTraceEvent(endGpuRasterizerDrawJson),
];

const Map<String, dynamic> gpuRasterizerDrawJson = {
  'name': 'GPURasterizer::Draw',
  'cat': 'Embedder',
  'tid': testGpuThreadId,
  'pid': 94955,
  'ts': 118039651469,
  'ph': 'B',
  'args': {}
};

const Map<String, dynamic> pipelineConsumeJson = {
  'name': 'PipelineConsume',
  'cat': 'Embedder',
  'tid': testGpuThreadId,
  'pid': 94955,
  'ts': 118039651470,
  'ph': 'B',
  'args': {}
};
const Map<String, dynamic> endPipelineConsumeJson = {
  'name': 'PipelineConsume',
  'cat': 'Embedder',
  'tid': testGpuThreadId,
  'pid': 94955,
  'ts': 118039679870,
  'ph': 'E',
  'args': {}
};

const Map<String, dynamic> endGpuRasterizerDrawJson = {
  'name': 'GPURasterizer::Draw',
  'cat': 'Embedder',
  'tid': testGpuThreadId,
  'pid': 94955,
  'ts': 118039679873,
  'ph': 'E',
  'args': {}
};

// Mark: OfflineTimelineData.
final goldenTraceEventsJson = List.from(
    goldenUiTraceEvents.map((trace) => trace.json).toList()
      ..addAll(goldenGpuTraceEvents.map((trace) => trace.json).toList()));

final offlineTimelineDataJson = {
  TimelineData.traceEventsKey: goldenTraceEventsJson,
  TimelineData.cpuProfileKey: goldenCpuProfileDataJson,
  TimelineData.selectedEventKey: vsyncEvent.json,
  TimelineData.devToolsScreenKey: timelineScreenId,
};
