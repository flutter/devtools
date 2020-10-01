// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'dart:convert';

import 'package:devtools_app/src/timeline/timeline_model.dart';
import 'package:devtools_app/src/trace_event.dart';
import 'package:devtools_app/src/utils.dart';

import 'cpu_profile_test_data.dart';
import 'test_utils.dart';

const testUiThreadId = 1;
const testRasterThreadId = 2;
const testUnknownThreadId = 3;

final frameStartEvent = testTraceEventWrapper({
  'name': 'PipelineItem',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039650806,
  'ph': 's',
  'id': 'f1',
  'args': {}
});

final frameEndEvent = testTraceEventWrapper({
  'name': 'PipelineItem',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 94955,
  'ts': 118039679872,
  'ph': 'f',
  'bp': 'e',
  'id': 'f1',
  'args': {}
});

final testFrame0 = TimelineFrame('id_0')
  ..setEventFlow(goldenUiTimelineEvent)
  ..setEventFlow(goldenRasterTimelineEvent);

final testFrame1 = TimelineFrame('id_1')
  ..setEventFlow(goldenUiTimelineEvent)
  ..setEventFlow(goldenRasterTimelineEvent);

final jankyFrame = TimelineFrame('jankyFrame')
  // ignore: invalid_use_of_visible_for_testing_member
  ..eventFlows[0] = (goldenUiTimelineEvent.deepCopy()
    ..time = (TimeRange()
      ..start = const Duration(milliseconds: 50)
      ..end = const Duration(milliseconds: 70)))
  // ignore: invalid_use_of_visible_for_testing_member
  ..eventFlows[1] = (goldenRasterTimelineEvent.deepCopy()
    ..time = (TimeRange()
      ..start = const Duration(milliseconds: 68)
      ..end = const Duration(milliseconds: 75)));

// Mark: UI golden data.
// None of the following data should be modified. If you have a need to modify
// any of the below events for a test, make a copy and modify the copy.
final vsyncEvent = testSyncTimelineEvent(vsyncTrace)
  ..type = TimelineEventType.ui
  ..addEndEvent(endVsyncTrace);

final animatorBeginFrameEvent = testSyncTimelineEvent(animatorBeginFrameTrace)
  ..type = TimelineEventType.ui
  ..addEndEvent(endAnimatorBeginFrameTrace);

final frameworkWorkloadEvent = testSyncTimelineEvent(frameworkWorkloadTrace)
  ..type = TimelineEventType.ui
  ..addEndEvent(endFrameworkWorkloadTrace);

final engineBeginFrameEvent = testSyncTimelineEvent(engineBeginFrameTrace)
  ..type = TimelineEventType.ui
  ..addEndEvent(endEngineBeginFrameTrace);

final frameEvent = testSyncTimelineEvent(frameTrace)
  ..time.end = const Duration(microseconds: 118039652334)
  ..type = TimelineEventType.ui;

final animateEvent = testSyncTimelineEvent(animateTrace)
  ..time.end = const Duration(microseconds: 118039650871)
  ..type = TimelineEventType.ui;

final layoutEvent = testSyncTimelineEvent(layoutTrace)
  ..time.end = const Duration(microseconds: 118039651087)
  ..type = TimelineEventType.ui;

final buildEvent = testSyncTimelineEvent(buildTrace)
  ..time.end = const Duration(microseconds: 118039651017)
  ..type = TimelineEventType.ui;

final compositingBitsEvent = testSyncTimelineEvent(compositingBitsTrace)
  ..time.end = const Duration(microseconds: 118039651090)
  ..type = TimelineEventType.ui;

final paintEvent = testSyncTimelineEvent(paintTrace)
  ..time.end = const Duration(microseconds: 118039651165)
  ..type = TimelineEventType.ui;

final compositingEvent = testSyncTimelineEvent(compositingTrace)
  ..time.end = const Duration(microseconds: 118039651460)
  ..type = TimelineEventType.ui;

final semanticsEvent = testSyncTimelineEvent(semanticsTrace)
  ..time.end = const Duration(microseconds: 118039652210)
  ..type = TimelineEventType.ui;

final finalizeTreeEvent = testSyncTimelineEvent(finalizeTreeTrace)
  ..time.end = const Duration(microseconds: 118039652308)
  ..type = TimelineEventType.ui;

final goldenUiTimelineEvent = vsyncEvent
  ..addAllChildren([
    animatorBeginFrameEvent
      ..parent = vsyncEvent
      ..addAllChildren([
        frameworkWorkloadEvent
          ..parent = animatorBeginFrameEvent
          ..addAllChildren([
            engineBeginFrameEvent
              ..parent = frameworkWorkloadEvent
              ..addAllChildren([
                frameEvent
                  ..parent = engineBeginFrameEvent
                  ..addAllChildren([
                    animateEvent..parent = frameEvent,
                    layoutEvent
                      ..parent = frameEvent
                      ..addChild(buildEvent..parent = layoutEvent),
                    compositingBitsEvent..parent = frameEvent,
                    paintEvent..parent = frameEvent,
                    compositingEvent..parent = frameEvent,
                    semanticsEvent..parent = frameEvent,
                    finalizeTreeEvent..parent = frameEvent,
                  ])
              ]),
          ]),
      ]),
  ]);

const goldenUiString = '  VSYNC [118039650802 μs - 118039652422 μs]\n'
    '    Animator::BeginFrame [118039650803 μs - 118039652421 μs]\n'
    '      Framework Workload [118039650807 μs - 118039652412 μs]\n'
    '        Engine::BeginFrame [118039650809 μs - 118039652411 μs]\n'
    '          Frame [118039650834 μs - 118039652334 μs]\n'
    '            Animate [118039650838 μs - 118039650871 μs]\n'
    '            Layout [118039650876 μs - 118039651087 μs]\n'
    '              Build [118039650984 μs - 118039651017 μs]\n'
    '            Compositing bits [118039651088 μs - 118039651090 μs]\n'
    '            Paint [118039651091 μs - 118039651165 μs]\n'
    '            Compositing [118039651166 μs - 118039651460 μs]\n'
    '            Semantics [118039651462 μs - 118039652210 μs]\n'
    '            Finalize tree [118039652219 μs - 118039652308 μs]\n';

final goldenUiTraceEvents = [
  vsyncTrace,
  animatorBeginFrameTrace,
  frameworkWorkloadTrace,
  engineBeginFrameTrace,
  animateTrace,
  buildTrace,
  layoutTrace,
  compositingBitsTrace,
  paintTrace,
  compositingTrace,
  semanticsTrace,
  finalizeTreeTrace,
  frameTrace,
  endEngineBeginFrameTrace,
  endFrameworkWorkloadTrace,
  endAnimatorBeginFrameTrace,
  endVsyncTrace,
];

final outOfOrderUiTraceEvents = [
  endVsyncTrace,
  endAnimatorBeginFrameTrace,
  endFrameworkWorkloadTrace,
  endEngineBeginFrameTrace,
  frameTrace,
  finalizeTreeTrace,
  semanticsTrace,
  compositingTrace,
  paintTrace,
  compositingBitsTrace,
  layoutTrace,
  buildTrace,
  animateTrace,
  engineBeginFrameTrace,
  frameworkWorkloadTrace,
  animatorBeginFrameTrace,
  vsyncTrace,
];

final uiTraceEventsWithDuplicates = [
  vsyncTrace,
  vsyncTrace,
  animatorBeginFrameTrace,
  frameworkWorkloadTrace,
  engineBeginFrameTrace,
  animateTrace,
  buildTrace,
  layoutTrace,
  compositingBitsTrace,
  paintTrace,
  compositingTrace,
  semanticsTrace,
  finalizeTreeTrace,
  frameTrace,
  endEngineBeginFrameTrace,
  endFrameworkWorkloadTrace,
  endAnimatorBeginFrameTrace,
  endVsyncTrace,
  endVsyncTrace,
];

final httpEvent = testSyncTimelineEvent(httpTrace);

final httpTrace = testTraceEventWrapper({
  'name': 'HTTP CLIENT GET',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 28035,
  'ts': 118039650802,
  'ph': 'b',
  'args': {
    'filterKey': 'HTTP/client',
  }
});

final vsyncTrace = testTraceEventWrapper({
  'name': 'VSYNC',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039650802,
  'ph': 'B',
  'args': {}
});
final animatorBeginFrameTrace = testTraceEventWrapper({
  'name': 'Animator::BeginFrame',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039650803,
  'ph': 'B',
  'args': {}
});
final frameworkWorkloadTrace = testTraceEventWrapper({
  'name': 'Framework Workload',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039650807,
  'ph': 'B',
  'args': {'mode': 'basic', 'frame': 'odd'}
});
final engineBeginFrameTrace = testTraceEventWrapper({
  'name': 'Engine::BeginFrame',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039650809,
  'ph': 'B',
  'args': {}
});
final animateTrace = testTraceEventWrapper({
  'name': 'Animate',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039650838,
  'ph': 'X',
  'dur': 33,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
});
final buildTrace = testTraceEventWrapper({
  'name': 'Build',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039650984,
  'ph': 'X',
  'dur': 33,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
});
final layoutTrace = testTraceEventWrapper({
  'name': 'Layout',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039650876,
  'ph': 'X',
  'dur': 211,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
});
final compositingBitsTrace = testTraceEventWrapper({
  'name': 'Compositing bits',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039651088,
  'ph': 'X',
  'dur': 2,
  'args': {'isolateNumber': '993728060'}
});
final paintTrace = testTraceEventWrapper({
  'name': 'Paint',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039651091,
  'ph': 'X',
  'dur': 74,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
});
final compositingTrace = testTraceEventWrapper({
  'name': 'Compositing',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039651166,
  'ph': 'X',
  'dur': 294,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
});
final semanticsTrace = testTraceEventWrapper({
  'name': 'Semantics',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039651462,
  'ph': 'X',
  'dur': 748,
  'args': {'isolateNumber': '993728060'}
});
final finalizeTreeTrace = testTraceEventWrapper({
  'name': 'Finalize tree',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039652219,
  'ph': 'X',
  'dur': 89,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
});

final frameTrace = testTraceEventWrapper({
  'name': 'Frame',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039650834,
  'ph': 'X',
  'dur': 1500,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'}
});
final endVsyncTrace = testTraceEventWrapper({
  'name': 'VSYNC',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039652422,
  'ph': 'E',
  'args': {}
});
final endAnimatorBeginFrameTrace = testTraceEventWrapper({
  'name': 'Animator::BeginFrame',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039652421,
  'ph': 'E',
  'args': {}
});
final endFrameworkWorkloadTrace = testTraceEventWrapper({
  'name': 'Framework Workload',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039652412,
  'ph': 'E',
  'args': {}
});
final endEngineBeginFrameTrace = testTraceEventWrapper({
  'name': 'Engine::BeginFrame',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 118039652411,
  'ph': 'E',
  'args': {}
});

// Mark: Raster golden data. This data is abbreviated in comparison to the UI
// golden data. We do not need both data sets to be complete for testing.
// None of the following data should be modified. If you have a need to modify
// any of the below events for a test, make a copy and modify the copy.
final gpuRasterizerDrawEvent = testSyncTimelineEvent(gpuRasterizerDrawTrace)
  ..type = TimelineEventType.raster
  ..addEndEvent(endGpuRasterizerDrawTrace);

final pipelineConsumeEvent = testSyncTimelineEvent(pipelineConsumeTrace)
  ..type = TimelineEventType.raster
  ..addEndEvent(endPipelineConsumeTrace);

final goldenRasterTimelineEvent = gpuRasterizerDrawEvent
  ..addChild(pipelineConsumeEvent);

const goldenRasterString =
    '  GPURasterizer::Draw [118039651469 μs - 118039679873 μs]\n'
    '    PipelineConsume [118039651470 μs - 118039679870 μs]\n';

final goldenRasterTraceEvents = [
  gpuRasterizerDrawTrace,
  pipelineConsumeTrace,
  endPipelineConsumeTrace,
  endGpuRasterizerDrawTrace,
];

final gpuRasterizerDrawTrace = testTraceEventWrapper({
  'name': 'GPURasterizer::Draw',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 94955,
  'ts': 118039651469,
  'ph': 'B',
  'args': {
    'isolateId': 'id_001',
  }
});
final pipelineConsumeTrace = testTraceEventWrapper({
  'name': 'PipelineConsume',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 94955,
  'ts': 118039651470,
  'ph': 'B',
  'args': {}
});
final endPipelineConsumeTrace = testTraceEventWrapper({
  'name': 'PipelineConsume',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 94955,
  'ts': 118039679870,
  'ph': 'E',
  'args': {}
});
final endGpuRasterizerDrawTrace = testTraceEventWrapper({
  'name': 'GPURasterizer::Draw',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 94955,
  'ts': 118039679873,
  'ph': 'E',
  'args': {}
});

// Mark: AsyncTimelineData
final asyncEventWithInstantChildren = AsyncTimelineEvent(TraceEventWrapper(
  TraceEvent(jsonDecode(jsonEncode({
    'name': 'PipelineItem',
    'cat': 'Embedder',
    'tid': 19333,
    'pid': 94955,
    'ts': 118039650806,
    'ph': 's',
    'id': 'f1',
    'args': {
      'isolateId': 'id_001',
      'parentId': '07bf',
    },
  }))),
  0,
))
  ..addEndEvent(TraceEventWrapper(
    TraceEvent(jsonDecode(jsonEncode({
      'name': 'PipelineItem',
      'cat': 'Embedder',
      'tid': 19334,
      'pid': 94955,
      'ts': 118039679872,
      'ph': 'f',
      'bp': 'e',
      'id': 'f1',
      'args': {},
    }))),
    1,
  ))
  ..type = TimelineEventType.async
  ..addAllChildren([
    instantAsync1..time.end = instantAsync1.time.start,
    instantAsync2..time.end = instantAsync2.time.start,
    instantAsync3..time.end = instantAsync3.time.start,
  ]);

final instantAsync1 = AsyncTimelineEvent(TraceEventWrapper(
  TraceEvent(jsonDecode(jsonEncode({
    'name': 'Connection established',
    'cat': 'Dart',
    'tid': 19333,
    'pid': 94955,
    'ts': 118039660806,
    'ph': 'n',
    'id': 'f1',
    'args': {
      'isolateId': 'id_001',
    },
  }))),
  0,
));

final instantAsync2 = AsyncTimelineEvent(TraceEventWrapper(
  TraceEvent(jsonDecode(jsonEncode({
    'name': 'Connection established',
    'cat': 'Dart',
    'tid': 19334,
    'pid': 94955,
    'ts': 118039665806,
    'ph': 'n',
    'id': 'f1',
    'args': {
      'isolateId': 'id_001',
    },
  }))),
  1,
));

final instantAsync3 = AsyncTimelineEvent(TraceEventWrapper(
  TraceEvent(jsonDecode(jsonEncode({
    'name': 'Connection established',
    'cat': 'Dart',
    'tid': 19334,
    'pid': 94955,
    'ts': 118039670806,
    'ph': 'n',
    'id': 'f1',
    'args': {
      'isolateId': 'id_001',
    },
  }))),
  1,
));

final goldenAsyncTimelineEvent = asyncEventA
  ..addAllChildren([
    asyncEventB..addAllChildren([asyncEventB1, asyncEventB2]),
    asyncEventC..addAllChildren([asyncEventC1, asyncEventC2])
  ]);

const goldenAsyncString = '  A [193937056864 μs - 193938740982 μs]\n'
    '    B [193937113560 μs - 193937382819 μs]\n'
    '      B1 [193937141769 μs - 193937225475 μs]\n'
    '      B2 [193937173019 μs - 193938740983 μs]\n'
    '    C [193937168961 μs - 193937485018 μs]\n'
    '      C1 [193937220903 μs - 193937326225 μs]\n'
    '      C2 [193937378812 μs - 193937432875 μs]\n';

final asyncEventA = AsyncTimelineEvent(asyncStartATrace)
  ..addEndEvent(asyncEndATrace);
final asyncEventB = AsyncTimelineEvent(asyncStartBTrace)
  ..addEndEvent(asyncEndBTrace);
final asyncEventB1 = AsyncTimelineEvent(asyncStartB1Trace)
  ..addEndEvent(asyncEndB1Trace);
final asyncEventB2 = AsyncTimelineEvent(asyncStartB2Trace)
  ..addEndEvent(asyncEndB2Trace);
final asyncEventC = AsyncTimelineEvent(asyncStartCTrace)
  ..addEndEvent(asyncEndCTrace);
final asyncEventC1 = AsyncTimelineEvent(asyncStartC1Trace)
  ..addEndEvent(asyncEndC1Trace);
final asyncEventC2 = AsyncTimelineEvent(asyncStartC2Trace)
  ..addEndEvent(asyncEndC2Trace);
final asyncEventD = AsyncTimelineEvent(asyncStartDTrace)
  ..addEndEvent(asyncEndDTrace);

final asyncEventWithDeepOverlap = AsyncTimelineEvent(
    asyncStartTraceEventWithDeepOverlap)
  ..addEndEvent(asyncEndTraceEventWithDeepOverlap)
  ..addAllChildren([asyncEventWithDeepOverlap1, asyncEventWithDeepOverlap2]);
final asyncEventWithDeepOverlap1 = AsyncTimelineEvent(asyncStart1Trace)
  ..addEndEvent(asyncEnd1Trace)
  ..addChild(asyncEvent3);
final asyncEventWithDeepOverlap2 = AsyncTimelineEvent(asyncStart2Trace)
  ..addEndEvent(asyncEnd2Trace)
  ..addChild(asyncEvent4);
final asyncEvent3 = AsyncTimelineEvent(asyncStart3Trace)
  ..addEndEvent(asyncEnd3Trace);
final asyncEvent4 = AsyncTimelineEvent(asyncStart4Trace)
  ..addEndEvent(asyncEnd4Trace);

final asyncParentId1 = AsyncTimelineEvent(asyncParentStartId1)
  ..addEndEvent(asyncParentEndId1);
final asyncChildId1 = AsyncTimelineEvent(asyncChildStartId1)
  ..addEndEvent(asyncChildEndId1);
final asyncChildId2 = AsyncTimelineEvent(asyncChildStartId2)
  ..addEndEvent(asyncChildEndId2);

final asyncTraceEvents = [
  asyncStartATrace,
  asyncStartDTrace,
  asyncStartBTrace,
  asyncStartB1Trace,
  asyncStartCTrace,
  asyncStartC1Trace,
  asyncEndC1Trace,
  asyncStartC2Trace,
  asyncEndC2Trace,
  asyncStartB2Trace,
  asyncEndB1Trace,
  asyncEndB2Trace,
  asyncEndBTrace,
  asyncEndCTrace,
  asyncEndATrace,
  asyncEndDTrace,
];
final asyncStartATrace = testTraceEventWrapper({
  'name': 'A',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937056864,
  'ph': 'b',
  'id': '1',
  'args': {'isolateId': 'isolates/2139247553966975'},
});
final asyncEndATrace = testTraceEventWrapper({
  'name': 'A',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193938740982,
  'ph': 'e',
  'id': '1',
  'args': {'isolateId': 'isolates/2139247553966975'},
});
final asyncStartBTrace = testTraceEventWrapper({
  'name': 'B',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937113560,
  'ph': 'b',
  'id': '2',
  'args': {'parentId': '1', 'isolateId': 'isolates/2139247553966975'},
});
final asyncEndBTrace = testTraceEventWrapper({
  'name': 'B',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937382819,
  'ph': 'e',
  'id': '2',
  'args': {'isolateId': 'isolates/2139247553966975'},
});
final asyncStartB1Trace = testTraceEventWrapper({
  'name': 'B1',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937141769,
  'ph': 'b',
  'id': 'd',
  'args': {'parentId': '2', 'isolateId': 'isolates/2139247553966975'},
});
final asyncEndB1Trace = testTraceEventWrapper({
  'name': 'B1',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937225475,
  'ph': 'e',
  'id': 'd',
  'args': {'isolateId': 'isolates/2139247553966975'},
});
final asyncStartB2Trace = testTraceEventWrapper({
  'name': 'B2',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937173019,
  'ph': 'b',
  'id': 'e',
  'args': {'parentId': '2', 'isolateId': 'isolates/2139247553966975'},
});
final asyncEndB2Trace = testTraceEventWrapper({
  'name': 'B2',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193938740983,
  'ph': 'e',
  'id': 'e',
  'args': {'isolateId': 'isolates/2139247553966975'},
});
final asyncStartCTrace = testTraceEventWrapper({
  'name': 'C',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937168961,
  'ph': 'b',
  'id': '3',
  'args': {'parentId': '1', 'isolateId': 'isolates/2139247553966975'},
});
final asyncEndCTrace = testTraceEventWrapper({
  'name': 'C',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937485018,
  'ph': 'e',
  'id': '3',
  'args': {'isolateId': 'isolates/2139247553966975'},
});
final asyncStartC1Trace = testTraceEventWrapper({
  'name': 'C1',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937220903,
  'ph': 'b',
  'id': '11',
  'args': {'parentId': '3', 'isolateId': 'isolates/2139247553966975'}
});
final asyncEndC1Trace = testTraceEventWrapper({
  'name': 'C1',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937326225,
  'ph': 'e',
  'id': '11',
  'args': {'isolateId': 'isolates/2139247553966975'}
});
final asyncStartC2Trace = testTraceEventWrapper({
  'name': 'C2',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937378812,
  'ph': 'b',
  'id': '12',
  'args': {'parentId': '3', 'isolateId': 'isolates/2139247553966975'}
});
final asyncEndC2Trace = testTraceEventWrapper({
  'name': 'C2',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937432875,
  'ph': 'e',
  'id': '12',
  'args': {'isolateId': 'isolates/2139247553966975'}
});
final asyncStartDTrace = testTraceEventWrapper({
  'name': 'D',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937061035,
  'ph': 'b',
  'id': '7',
  'args': {'isolateId': 'isolates/2139247553966975'},
});
final asyncEndDTrace = testTraceEventWrapper({
  'name': 'D',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193938741076,
  'ph': 'e',
  'id': '7',
  'args': {'isolateId': 'isolates/2139247553966975'},
});

final asyncStartTraceEventWithDeepOverlap = testTraceEventWrapper({
  'name': 'EventWithDeepOverlap',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937000000,
  'ph': 'b',
  'id': '7',
  'args': {'isolateId': 'isolates/2139247553966975'},
});
final asyncEndTraceEventWithDeepOverlap = testTraceEventWrapper({
  'name': 'D',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193938000000,
  'ph': 'e',
  'id': '7',
  'args': {'isolateId': 'isolates/2139247553966975'},
});
final asyncStart1Trace = testTraceEventWrapper({
  'name': '1',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937000001,
  'ph': 'b',
  'id': '13',
  'args': {'parentId': '7', 'isolateId': 'isolates/2139247553966975'},
});
final asyncEnd1Trace = testTraceEventWrapper({
  'name': '1',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937500000,
  'ph': 'e',
  'id': '13',
  'args': {'isolateId': 'isolates/2139247553966975'},
});
final asyncStart2Trace = testTraceEventWrapper({
  'name': '2',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937500001,
  'ph': 'b',
  'id': '14',
  'args': {'parentId': '7', 'isolateId': 'isolates/2139247553966975'},
});
final asyncEnd2Trace = testTraceEventWrapper({
  'name': '2',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937999999,
  'ph': 'e',
  'id': '14',
  'args': {'isolateId': 'isolates/2139247553966975'},
});
final asyncStart3Trace = testTraceEventWrapper({
  'name': '3',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937000002,
  'ph': 'b',
  'id': '15',
  'args': {'parentId': '13', 'isolateId': 'isolates/2139247553966975'},
});
final asyncEnd3Trace = testTraceEventWrapper({
  'name': '3',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937500003,
  'ph': 'e',
  'id': '15',
  'args': {'isolateId': 'isolates/2139247553966975'},
});
final asyncStart4Trace = testTraceEventWrapper({
  'name': '4',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937500002,
  'ph': 'b',
  'id': '16',
  'args': {'parentId': '14', 'isolateId': 'isolates/2139247553966975'},
});
final asyncEnd4Trace = testTraceEventWrapper({
  'name': '4',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937999998,
  'ph': 'e',
  'id': '16',
  'args': {'isolateId': 'isolates/2139247553966975'},
});

final asyncParentStartId1 = testTraceEventWrapper({
  'name': 'asyncParentId1',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 1000,
  'ph': 'b',
  'id': '1',
  'args': {'isolateId': 'isolates/2139247553966975'},
});
final asyncParentEndId1 = testTraceEventWrapper({
  'name': 'asyncParentId1',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 2000,
  'ph': 'e',
  'id': '1',
  'args': {'isolateId': 'isolates/2139247553966975'},
});
final asyncChildStartId1 = testTraceEventWrapper({
  'name': 'asyncChildId1',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 1100,
  'ph': 'b',
  'id': '1',
  'args': {'isolateId': 'isolates/2139247553966975'},
});
final asyncChildEndId1 = testTraceEventWrapper({
  'name': 'asyncChildId1',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 1900,
  'ph': 'e',
  'id': '1',
  'args': {'isolateId': 'isolates/2139247553966975'},
});
final asyncChildStartId2 = testTraceEventWrapper({
  'name': 'asyncChildId1',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 1200,
  'ph': 'b',
  'id': '2',
  'args': {'isolateId': 'isolates/2139247553966975'},
});
final asyncChildEndId2 = testTraceEventWrapper({
  'name': 'asyncChildId1',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 1800,
  'ph': 'e',
  'id': '2',
  'args': {'isolateId': 'isolates/2139247553966975'},
});

// Mark: unknown event
final unknownEvent = SyncTimelineEvent(unknownEventBeginTrace)
  ..addEndEvent(unknownEventEndTrace);
final unknownEventBeginTrace = testTraceEventWrapper({
  'name': 'Unknown trace event',
  'cat': 'Dart',
  'tid': testUnknownThreadId,
  'pid': 51385,
  'ts': 193938741076,
  'ph': 'B',
  'id': '7',
  'args': {'isolateId': 'isolates/2139247553966975'},
});
final unknownEventEndTrace = testTraceEventWrapper({
  'name': 'Unknown trace event',
  'cat': 'Dart',
  'tid': testUnknownThreadId,
  'pid': 51385,
  'ts': 193938742076,
  'ph': 'E',
  'id': '7',
  'args': {'isolateId': 'isolates/2139247553966975'},
});

// Mark: OfflineTimelineData.
final goldenTraceEventsJson = List<Map<String, dynamic>>.from(
    goldenUiTraceEvents.map((trace) => trace.json).toList()
      ..addAll(goldenRasterTraceEvents.map((trace) => trace.json).toList()));

final offlineTimelineDataJson = {
  TimelineData.traceEventsKey: goldenTraceEventsJson,
  TimelineData.cpuProfileKey: goldenCpuProfileDataJson,
  TimelineData.selectedFrameIdKey: 'PipelineItem-1',
  TimelineData.selectedEventKey: vsyncEvent.json,
  TimelineData.displayRefreshRateKey: 120.0,
};

// Mark: Duration events with duplicate traces
final transformLayerStart1 = testTraceEventWrapper({
  'name': 'TransformLayer::Preroll',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 22283,
  'ts': 118039651669,
  'tts': 733287,
  'ph': 'B',
  'args': {}
});
final transformLayerStart2 = testTraceEventWrapper({
  'name': 'TransformLayer::Preroll',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 22283,
  'ts': 118039651869,
  'tts': 733289,
  'ph': 'B',
  'args': {}
});
final transformLayerEnd2 = testTraceEventWrapper({
  'name': 'TransformLayer::Preroll',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 22283,
  'ts': 118039679673,
  'tts': 733656,
  'ph': 'E',
  'args': {}
});
final transformLayerEnd1 = testTraceEventWrapper({
  'name': 'TransformLayer::Preroll',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 22283,
  'ts': 118039679673,
  'tts': 733656,
  'ph': 'E',
  'args': {}
});
final durationEventsWithDuplicateTraces = [
  gpuRasterizerDrawTrace,
  transformLayerStart1,
  transformLayerStart2,
  transformLayerEnd2,
  transformLayerEnd1,
  endGpuRasterizerDrawTrace,
];

final testTimelineJson = {
  'type': 'Timeline',
  'traceEvents': [
    {
      'name': 'thread_name',
      'tid': testUiThreadId,
      'args': {'name': '1.ui'},
    },
    {
      'name': 'thread_name',
      'tid': testRasterThreadId,
      'args': {'name': '1.raster'},
    },
    frameStartEvent.json,
    ...goldenTraceEventsJson,
    frameEndEvent.json,
  ],
  'timeOriginMicros': 118039650802,
  'timeExtentMicros': 118039679873 - 118039650802,
};

final gcEventStartTrace = testTraceEventWrapper({
  'name': 'ConcurrentMark',
  'cat': 'GC',
  'tid': 38147,
  'pid': 48043,
  'ts': 794638620007,
  'ph': 'B',
  'args': {'isolateGroupId': 'isolateGroups/18139071461608741439'}
});

final gcEventEndTrace = testTraceEventWrapper({
  'name': 'ConcurrentMark',
  'cat': 'GC',
  'tid': 25091,
  'pid': 48043,
  'ts': 794638633011,
  'ph': 'E',
  'args': {'isolateGroupId': 'isolateGroups/18139071461608741439'}
});

final gcEvent = testSyncTimelineEvent(gcEventStartTrace)
  ..addEndEvent(gcEventEndTrace);
