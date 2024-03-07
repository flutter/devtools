// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/devtools_app.dart';

import '../../test_infra/utils/test_utils.dart';
import 'cpu_profiler/cpu_profile.dart';
import 'performance_raster_stats.dart';

const testUiThreadId = 1;
const testRasterThreadId = 2;
const testUnknownThreadId = 3;

final threadNamesById = {
  45079: 'DartWorker (45079)',
  24835: 'Unknown (24835)',
  33119: 'DartWorker (33119)',
  38915: 'Unknown (38915)',
  24323: 'io.flutter.1.profiler (24323)',
  24067: 'io.flutter.1.io (24067)',
  testUiThreadId: 'io.flutter.1.ui (22787)',
  testRasterThreadId: 'io.flutter.1.raster (40963)',
  26371: 'DartWorker (26371)',
  37123: 'Dart Profiler ThreadInterrupter (37123)',
  775: 'io.flutter.1.platform (775)',
};

final testFrame0 = FlutterFrame.parse({
  'number': 0,
  'startTime': 10000,
  'elapsed': 20000,
  'build': 10000,
  'raster': 12000,
  'vsyncOverhead': 10,
});

final testFrame1 = FlutterFrame.parse({
  'number': 1,
  'startTime': 40000,
  'elapsed': 20000,
  'build': 16000,
  'raster': 16000,
  'vsyncOverhead': 1000,
});

final testFrame2 = FlutterFrame.parse({
  'number': 2,
  'startTime': 40000,
  'elapsed': 20000,
  'build': 16000,
  'raster': 16000,
  'vsyncOverhead': 1000,
});

final jankyFrame = FlutterFrame.parse({
  'number': 2,
  'startTime': 10000,
  'elapsed': 20000,
  'build': 18000,
  'raster': 18000,
  'vsyncOverhead': 1000,
});

final jankyFrameUiOnly = FlutterFrame.parse({
  'number': 3,
  'startTime': 10000,
  'elapsed': 20000,
  'build': 18000,
  'raster': 5000,
  'vsyncOverhead': 1000,
});

final jankyFrameRasterOnly = FlutterFrame.parse({
  'number': 4,
  'startTime': 10000,
  'elapsed': 20000,
  'build': 5000,
  'raster': 18000,
  'vsyncOverhead': 10,
});

final testFrameWithShaderJank = FlutterFrame.parse({
  'number': 5,
  'startTime': 10000,
  'elapsed': 200000,
  'build': 50000,
  'raster': 70000,
  'vsyncOverhead': 10,
})
  ..setEventFlow(goldenUiTimelineEvent)
  ..setEventFlow(rasterTimelineEventWithShaderJank);

final testFrameWithSubtleShaderJank = FlutterFrame.parse({
  'number': 6,
  'startTime': 10000,
  'elapsed': 200000,
  'build': 50000,
  'raster': 70000,
  'vsyncOverhead': 10,
})
  ..setEventFlow(goldenUiTimelineEvent)
  ..setEventFlow(rasterTimelineEventWithSubtleShaderJank);

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
  ..time.end = const Duration(microseconds: 193938742608)
  ..type = TimelineEventType.ui;

final animateEvent = testSyncTimelineEvent(animateTrace)
  ..time.end = const Duration(microseconds: 193938741145)
  ..type = TimelineEventType.ui;

final layoutEvent = testSyncTimelineEvent(layoutTrace)
  ..time.end = const Duration(microseconds: 193938741361)
  ..type = TimelineEventType.ui;

final buildEvent = testSyncTimelineEvent(buildTrace)
  ..time.end = const Duration(microseconds: 193938741291)
  ..type = TimelineEventType.ui;

final buildEvent2 = testSyncTimelineEvent(buildTrace2)
  ..time.end = const Duration(microseconds: 193938741350)
  ..type = TimelineEventType.ui;

final compositingBitsEvent = testSyncTimelineEvent(compositingBitsTrace)
  ..time.end = const Duration(microseconds: 193938741364)
  ..type = TimelineEventType.ui;

final paintEvent = testSyncTimelineEvent(paintTrace)
  ..time.end = const Duration(microseconds: 193938741439)
  ..type = TimelineEventType.ui;

final compositingEvent = testSyncTimelineEvent(compositingTrace)
  ..time.end = const Duration(microseconds: 193938741734)
  ..type = TimelineEventType.ui;

final semanticsEvent = testSyncTimelineEvent(semanticsTrace)
  ..time.end = const Duration(microseconds: 193938742484)
  ..type = TimelineEventType.ui;

final finalizeTreeEvent = testSyncTimelineEvent(finalizeTreeTrace)
  ..time.end = const Duration(microseconds: 193938742582)
  ..type = TimelineEventType.ui;

final intrinsicEvent1 = testSyncTimelineEvent(beginIntrinsics1Trace)
  ..time.end = const Duration(microseconds: 193938741240)
  ..type = TimelineEventType.ui;

final intrinsicEvent2 = testSyncTimelineEvent(beginIntrinsics2Trace)
  ..time.end = const Duration(microseconds: 193938741230)
  ..type = TimelineEventType.ui;

final canvasSaveLayerEvent = testSyncTimelineEvent(beginCanvasSaveLayerTrace)
  ..time.end = const Duration(microseconds: 193938741430)
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
                      ..addAllChildren([
                        intrinsicEvent1
                          ..parent = layoutEvent
                          ..addChild(intrinsicEvent2..parent = layoutEvent),
                        buildEvent..parent = layoutEvent,
                        buildEvent2..parent = layoutEvent,
                      ]),
                    compositingBitsEvent..parent = frameEvent,
                    paintEvent
                      ..parent = frameEvent
                      ..addChild(canvasSaveLayerEvent..parent = paintEvent),
                    compositingEvent..parent = frameEvent,
                    semanticsEvent..parent = frameEvent,
                    finalizeTreeEvent..parent = frameEvent,
                  ]),
              ]),
          ]),
      ]),
  ]);

const goldenUiString = '  VSYNC [193938741076 μs - 193938742696 μs]\n'
    '    Animator::BeginFrame [193938741077 μs - 193938742695 μs]\n'
    '      Framework Workload [193938741081 μs - 193938742686 μs]\n'
    '        Engine::BeginFrame [193938741083 μs - 193938742685 μs]\n'
    '          Frame [193938741108 μs - 193938742608 μs]\n'
    '            Animate [193938741112 μs - 193938741145 μs]\n'
    '            Layout [193938741150 μs - 193938741361 μs]\n'
    '              RenderFlex intrinsics [193938741160 μs - 193938741240 μs]\n'
    '                RenderConstrainedBox intrinsics [193938741200 μs - 193938741230 μs]\n'
    '              Build [193938741258 μs - 193938741291 μs]\n'
    '              Build [193938741300 μs - 193938741350 μs]\n'
    '            Compositing bits [193938741362 μs - 193938741364 μs]\n'
    '            Paint [193938741365 μs - 193938741439 μs]\n'
    '              ui.Canvas::saveLayer (Recorded) [193938741425 μs - 193938741430 μs]\n'
    '            Compositing [193938741440 μs - 193938741734 μs]\n'
    '            Semantics [193938741736 μs - 193938742484 μs]\n'
    '            Finalize tree [193938742493 μs - 193938742582 μs]\n';

final goldenUiTraceEvents = <TraceEventWrapper>[
  vsyncTrace,
  animatorBeginFrameTrace,
  frameworkWorkloadTrace,
  engineBeginFrameTrace,
  animateTrace,
  beginIntrinsics1Trace,
  beginIntrinsics2Trace,
  endIntrinsics2Trace,
  endIntrinsics1Trace,
  buildTrace,
  buildTrace2,
  layoutTrace,
  compositingBitsTrace,
  paintTrace,
  beginCanvasSaveLayerTrace,
  endCanvasSaveLayerTrace,
  compositingTrace,
  semanticsTrace,
  finalizeTreeTrace,
  frameTrace,
  endEngineBeginFrameTrace,
  endFrameworkWorkloadTrace,
  endAnimatorBeginFrameTrace,
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
  },
});

final vsyncTrace = testTraceEventWrapper({
  'name': 'VSYNC',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 193938741076,
  'ph': 'B',
  'args': {},
});
final animatorBeginFrameTrace = testTraceEventWrapper({
  'name': 'Animator::BeginFrame',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 193938741077,
  'ph': 'B',
  'args': {'frame_number': '1'},
});
final frameworkWorkloadTrace = testTraceEventWrapper({
  'name': 'Framework Workload',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 193938741081,
  'ph': 'B',
  'args': {'mode': 'basic', 'frame': 'odd'},
});
final engineBeginFrameTrace = testTraceEventWrapper({
  'name': 'Engine::BeginFrame',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 193938741083,
  'ph': 'B',
  'args': {},
});
final animateTrace = testTraceEventWrapper({
  'name': 'Animate',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 193938741112,
  'ph': 'X',
  'dur': 33,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'},
});
final buildTrace = testTraceEventWrapper({
  'name': 'Build',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 193938741258,
  'ph': 'X',
  'dur': 33,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'},
});
final buildTrace2 = testTraceEventWrapper({
  'name': 'Build',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 193938741300,
  'ph': 'X',
  'dur': 50,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'},
});
final layoutTrace = testTraceEventWrapper({
  'name': 'Layout',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 193938741150,
  'ph': 'X',
  'dur': 211,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'},
});
final compositingBitsTrace = testTraceEventWrapper({
  'name': 'Compositing bits',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 193938741362,
  'ph': 'X',
  'dur': 2,
  'args': {'isolateNumber': '993728060'},
});
final paintTrace = testTraceEventWrapper({
  'name': 'Paint',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 193938741365,
  'ph': 'X',
  'dur': 74,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'},
});
final compositingTrace = testTraceEventWrapper({
  'name': 'Compositing',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 193938741440,
  'ph': 'X',
  'dur': 294,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'},
});
final semanticsTrace = testTraceEventWrapper({
  'name': 'Semantics',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 193938741736,
  'ph': 'X',
  'dur': 748,
  'args': {'isolateNumber': '993728060'},
});
final finalizeTreeTrace = testTraceEventWrapper({
  'name': 'Finalize tree',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 193938742493,
  'ph': 'X',
  'dur': 89,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'},
});

final frameTrace = testTraceEventWrapper({
  'name': 'Frame',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 193938741108,
  'ph': 'X',
  'dur': 1500,
  'args': {'mode': 'basic', 'isolateNumber': '993728060'},
});
final endVsyncTrace = testTraceEventWrapper({
  'name': 'VSYNC',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 193938742696,
  'ph': 'E',
  'args': {},
});
final endAnimatorBeginFrameTrace = testTraceEventWrapper({
  'name': 'Animator::BeginFrame',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 193938742695,
  'ph': 'E',
  'args': {},
});
final endFrameworkWorkloadTrace = testTraceEventWrapper({
  'name': 'Framework Workload',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 193938742686,
  'ph': 'E',
  'args': {},
});
final endEngineBeginFrameTrace = testTraceEventWrapper({
  'name': 'Engine::BeginFrame',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 94955,
  'ts': 193938742685,
  'ph': 'E',
  'args': {},
});

final beginIntrinsics1Trace = testTraceEventWrapper({
  'name': 'RenderFlex intrinsics',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 33036,
  'ts': 193938741160,
  'tts': 1760440,
  'ph': 'B',
  'args': {
    'intrinsics dimension': 'maxHeight',
    'intrinsics argument': '375.0',
    'isolateId': 'isolates/3152451962062387',
    'isolateGroupId': 'isolateGroups/12069909095439033329',
  },
});

final beginIntrinsics2Trace = testTraceEventWrapper({
  'name': 'RenderConstrainedBox intrinsics',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 33036,
  'ts': 193938741200,
  'tts': 1763839,
  'ph': 'B',
  'args': {
    'intrinsics dimension': 'maxHeight',
    'intrinsics argument': '375.0',
    'isolateId': 'isolates/3152451962062387',
    'isolateGroupId': 'isolateGroups/12069909095439033329',
  },
});

final endIntrinsics2Trace = testTraceEventWrapper({
  'name': 'RenderConstrainedBox intrinsics',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 33036,
  'ts': 193938741230,
  'tts': 1764322,
  'ph': 'E',
  'args': {
    'intrinsics dimension': 'maxHeight',
    'intrinsics argument': '375.0',
    'isolateId': 'isolates/3152451962062387',
    'isolateGroupId': 'isolateGroups/12069909095439033329',
  },
});

final endIntrinsics1Trace = testTraceEventWrapper({
  'name': 'RenderFlex intrinsics',
  'cat': 'Dart',
  'tid': testUiThreadId,
  'pid': 33036,
  'ts': 193938741240,
  'tts': 1764422,
  'ph': 'E',
  'args': {
    'intrinsics dimension': 'maxHeight',
    'intrinsics argument': '375.0',
    'isolateId': 'isolates/3152451962062387',
    'isolateGroupId': 'isolateGroups/12069909095439033329',
  },
});

final beginCanvasSaveLayerTrace = testTraceEventWrapper({
  'name': 'ui.Canvas::saveLayer (Recorded)',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 33036,
  'ts': 193938741425,
  'tts': 1845001,
  'ph': 'B',
  'args': {
    'isolateId': 'isolates/3152451962062387',
    'isolateGroupId': 'isolateGroups/12069909095439033329',
  },
});

final endCanvasSaveLayerTrace = testTraceEventWrapper({
  'name': 'ui.Canvas::saveLayer (Recorded)',
  'cat': 'Embedder',
  'tid': testUiThreadId,
  'pid': 33036,
  'ts': 193938741430,
  'tts': 1845004,
  'ph': 'E',
  'args': {
    'isolateId': 'isolates/3152451962062387',
    'isolateGroupId': 'isolateGroups/12069909095439033329',
  },
});

// Mark: Raster golden data. This data is abbreviated in comparison to the UI
// golden data. We do not need both data sets to be complete for testing.
// None of the following data should be modified. If you have a need to modify
// any of the below events for a test, make a copy and modify the copy.
final gpuRasterizerDrawEvent = testSyncTimelineEvent(gpuRasterizerDrawTrace)
  ..type = TimelineEventType.raster
  ..addEndEvent(endGpuRasterizerDrawTrace);

final rasterizerDoDrawEvent = testSyncTimelineEvent(rasterizerDoDrawTrace)
  ..type = TimelineEventType.raster
  ..addEndEvent(endRasterizerDoDrawTrace);

final pipelineConsumeEvent = testSyncTimelineEvent(pipelineConsumeTrace)
  ..type = TimelineEventType.raster
  ..addEndEvent(endPipelineConsumeTrace);

final goldenRasterTimelineEvent = gpuRasterizerDrawEvent
  ..addChild(pipelineConsumeEvent);

const goldenRasterString =
    '  GPURasterizer::Draw [193938741743 μs - 193938770147 μs]\n'
    '    PipelineConsume [193938741744 μs - 193938770144 μs]\n';

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
  'ts': 193938741743,
  'ph': 'B',
  'args': {
    'isolateId': 'id_001',
    'frame_number': '1',
  },
});
final pipelineConsumeTrace = testTraceEventWrapper({
  'name': 'PipelineConsume',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 94955,
  'ts': 193938741744,
  'ph': 'B',
  'args': {},
});
final endPipelineConsumeTrace = testTraceEventWrapper({
  'name': 'PipelineConsume',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 94955,
  'ts': 193938770144,
  'ph': 'E',
  'args': {},
});
final endGpuRasterizerDrawTrace = testTraceEventWrapper({
  'name': 'GPURasterizer::Draw',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 94955,
  'ts': 193938770147,
  'ph': 'E',
  'args': {},
});
final rasterizerDoDrawTrace = testTraceEventWrapper({
  'name': 'Rasterizer::DoDraw',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 94955,
  'ts': 193938741743,
  'ph': 'B',
  'args': {
    'isolateId': 'id_001',
    'frame_number': '1',
  },
});
final endRasterizerDoDrawTrace = testTraceEventWrapper({
  'name': 'Rasterizer::DoDraw',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 94955,
  'ts': 193938770147,
  'ph': 'E',
  'args': {},
});

final rasterTimelineEventWithShaderJank =
    testSyncTimelineEvent(gpuRasterizerDrawWithShaderJankTrace)
      ..type = TimelineEventType.raster
      ..addEndEvent(endGpuRasterizerDrawWithShaderJankTrace);
final gpuRasterizerDrawWithShaderJankTrace = testTraceEventWrapper({
  'name': 'GPURasterizer::Draw',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 94955,
  'ts': 193938740000,
  'ph': 'B',
  'args': {
    'devtoolsTag': 'shaders',
  },
});
final endGpuRasterizerDrawWithShaderJankTrace = testTraceEventWrapper({
  'name': 'GPURasterizer::Draw',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 94955,
  'ts': 193938790000,
  'ph': 'E',
  'args': {},
});

final rasterTimelineEventWithSubtleShaderJank =
    testSyncTimelineEvent(gpuRasterizerDrawWithSubtleShaderJankTrace)
      ..type = TimelineEventType.raster
      ..addEndEvent(endGpuRasterizerDrawWithSubtleShaderJankTrace)
      ..addChild(
        subtleShaderJankChildEvent..addChild(subtleShaderJankGrandchildEvent),
      );
final subtleShaderJankChildEvent = testSyncTimelineEvent(shaderJankChildTrace)
  ..type = TimelineEventType.raster
  ..addEndEvent(endShaderJankChildTrace);
final subtleShaderJankGrandchildEvent =
    testSyncTimelineEvent(shaderJankGrandchildTrace)
      ..type = TimelineEventType.raster
      ..addEndEvent(endShaderJankGrandchildTrace);
final gpuRasterizerDrawWithSubtleShaderJankTrace = testTraceEventWrapper({
  'name': 'GPURasterizer::Draw',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 94955,
  'ts': 173938740000,
  'ph': 'B',
  'args': {
    'devtoolsTag': 'shaders',
  },
});
final endGpuRasterizerDrawWithSubtleShaderJankTrace = testTraceEventWrapper({
  'name': 'GPURasterizer::Draw',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 94955,
  'ts': 173938744000,
  'ph': 'E',
  'args': {},
});
final shaderJankChildTrace = testTraceEventWrapper({
  'name': 'GPURasterizer::Draw',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 94955,
  'ts': 173938741000,
  'ph': 'B',
  'args': {},
});
final endShaderJankChildTrace = testTraceEventWrapper({
  'name': 'GPURasterizer::Draw',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 94955,
  'ts': 173938743000,
  'ph': 'E',
  'args': {},
});
final shaderJankGrandchildTrace = testTraceEventWrapper({
  'name': 'GPURasterizer::Draw',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 94955,
  'ts': 173938741500,
  'ph': 'B',
  'args': {
    'devtoolsTag': 'shaders',
  },
});
final endShaderJankGrandchildTrace = testTraceEventWrapper({
  'name': 'GPURasterizer::Draw',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 94955,
  'ts': 173938742500,
  'ph': 'E',
  'args': {},
});

// Mark: AsyncTimelineData
final asyncEventWithInstantChildren = AsyncTimelineEvent(
  TraceEventWrapper(
    ChromeTraceEvent(
      jsonDecode(
        jsonEncode({
          'name': 'PipelineItem',
          'cat': 'Embedder',
          'tid': 19333,
          'pid': 94955,
          'ts': 193938741080,
          'ph': 's',
          'id': 'f1',
          'args': {
            'isolateId': 'id_001',
            'parentId': '07bf',
          },
        }),
      ),
    ),
    0,
  ),
)
  ..addEndEvent(
    TraceEventWrapper(
      ChromeTraceEvent(
        jsonDecode(
          jsonEncode({
            'name': 'PipelineItem',
            'cat': 'Embedder',
            'tid': 19334,
            'pid': 94955,
            'ts': 193938770146,
            'ph': 'f',
            'bp': 'e',
            'id': 'f1',
            'args': {},
          }),
        ),
      ),
      1,
    ),
  )
  ..type = TimelineEventType.async
  ..addAllChildren([
    instantAsync1..time.end = instantAsync1.time.start,
    instantAsync2..time.end = instantAsync2.time.start,
    instantAsync3..time.end = instantAsync3.time.start,
  ]);

final instantAsync1 = AsyncTimelineEvent(
  TraceEventWrapper(
    ChromeTraceEvent(
      jsonDecode(
        jsonEncode({
          'name': 'Connection established',
          'cat': 'Dart',
          'tid': 19333,
          'pid': 94955,
          'ts': 193938751080,
          'ph': 'n',
          'id': 'f1',
          'args': {
            'isolateId': 'id_001',
          },
        }),
      ),
    ),
    0,
  ),
);

final instantAsync2 = AsyncTimelineEvent(
  TraceEventWrapper(
    ChromeTraceEvent(
      jsonDecode(
        jsonEncode({
          'name': 'Connection established',
          'cat': 'Dart',
          'tid': 19334,
          'pid': 94955,
          'ts': 193938756080,
          'ph': 'n',
          'id': 'f1',
          'args': {
            'isolateId': 'id_001',
          },
        }),
      ),
    ),
    1,
  ),
);

final instantAsync3 = AsyncTimelineEvent(
  TraceEventWrapper(
    ChromeTraceEvent(
      jsonDecode(
        jsonEncode({
          'name': 'Connection established',
          'cat': 'Dart',
          'tid': 19334,
          'pid': 94955,
          'ts': 193938761080,
          'ph': 'n',
          'id': 'f1',
          'args': {
            'isolateId': 'id_001',
          },
        }),
      ),
    ),
    1,
  ),
);

final goldenAsyncTimelineEvent = asyncEventA
  ..addAllChildren([
    asyncEventB..addAllChildren([asyncEventB1, asyncEventB2]),
    asyncEventC..addAllChildren([asyncEventC1, asyncEventC2]),
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
  asyncStartTraceEventWithDeepOverlap,
)
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
  'args': {'parentId': '3', 'isolateId': 'isolates/2139247553966975'},
});
final asyncEndC1Trace = testTraceEventWrapper({
  'name': 'C1',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937326225,
  'ph': 'e',
  'id': '11',
  'args': {'isolateId': 'isolates/2139247553966975'},
});
final asyncStartC2Trace = testTraceEventWrapper({
  'name': 'C2',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937378812,
  'ph': 'b',
  'id': '12',
  'args': {'parentId': '3', 'isolateId': 'isolates/2139247553966975'},
});
final asyncEndC2Trace = testTraceEventWrapper({
  'name': 'C2',
  'cat': 'Dart',
  'tid': 4875,
  'pid': 51385,
  'ts': 193937432875,
  'ph': 'e',
  'id': '12',
  'args': {'isolateId': 'isolates/2139247553966975'},
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

// Mark: OfflinePerformanceData.
final goldenTraceEventsJson = List<Map<String, dynamic>>.of(
  goldenUiTraceEvents.map((trace) => trace.json).toList()
    ..addAll(goldenRasterTraceEvents.map((trace) => trace.json).toList()),
);

final offlinePerformanceDataJson = {
  PerformanceData.traceEventsKey: goldenTraceEventsJson,
  PerformanceData.cpuProfileKey: goldenCpuProfileDataJson,
  PerformanceData.selectedFrameIdKey: 1,
  PerformanceData.selectedEventKey: vsyncEvent.json,
  PerformanceData.displayRefreshRateKey: 120.0,
  PerformanceData.rasterStatsKey: rasterStatsFromDevToolsJson,
};

// Mark: Duration events with duplicate traces
final transformLayerStart1 = testTraceEventWrapper({
  'name': 'TransformLayer::Preroll',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 22283,
  'ts': 193938741750,
  'tts': 733287,
  'ph': 'B',
  'args': {},
});
final transformLayerStart2 = testTraceEventWrapper({
  'name': 'TransformLayer::Preroll',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 22283,
  'ts': 193938741850,
  'tts': 733289,
  'ph': 'B',
  'args': {},
});
final transformLayerEnd2 = testTraceEventWrapper({
  'name': 'TransformLayer::Preroll',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 22283,
  'ts': 193938770000,
  'tts': 733656,
  'ph': 'E',
  'args': {},
});
final transformLayerEnd1 = testTraceEventWrapper({
  'name': 'TransformLayer::Preroll',
  'cat': 'Embedder',
  'tid': testRasterThreadId,
  'pid': 22283,
  'ts': 193938770000,
  'tts': 733656,
  'ph': 'E',
  'args': {},
});
final durationEventsWithDuplicateTraces = <TraceEventWrapper>[
  gpuRasterizerDrawTrace,
  transformLayerStart1,
  transformLayerStart2,
  transformLayerEnd2,
  transformLayerEnd1,
  endGpuRasterizerDrawTrace,
];

final asyncEventsWithChildrenWithDifferentIds = [
  testTraceEventWrapper({
    'name': 'PipelineItem',
    'cat': 'Embedder',
    'tid': 22019,
    'pid': 18510,
    'ts': 5294235082,
    'ph': 'b',
    'id': '1',
    'args': {'isolateId': 'isolates/677008524697083'},
  }),
  testTraceEventWrapper({
    'name': 'PipelineProduce',
    'cat': 'Embedder',
    'tid': 22019,
    'pid': 18510,
    'ts': 5294235082,
    'ph': 'b',
    'id': '1',
    'args': {'isolateId': 'isolates/677008524697083'},
  }),
  testTraceEventWrapper({
    'name': 'PipelineProduce',
    'cat': 'Embedder',
    'tid': 22019,
    'pid': 18510,
    'ts': 5294236800,
    'ph': 'e',
    'id': '1',
    'args': {'isolateId': 'isolates/677008524697083'},
  }),
  // Child of PipelineItem with id '1'
  testTraceEventWrapper({
    'name': 'ImageCache.putIfAbsent',
    'cat': 'Dart',
    'tid': 22019,
    'pid': 18510,
    'ts': 5294246630,
    'ph': 'b',
    'id': '1',
    'args': {'isolateId': 'isolates/677008524697083'},
  }),
  // Child of PipelineItem with id '2' (parent manually specified)
  testTraceEventWrapper({
    'name': 'listener',
    'cat': 'Dart',
    'tid': 22019,
    'pid': 18510,
    'ts': 5294251242,
    'ph': 'b',
    'id': '2',
    'args': {'parentId': '1'},
  }),
  testTraceEventWrapper({
    'name': 'listener',
    'cat': 'Dart',
    'tid': 22019,
    'pid': 18510,
    'ts': 5294272684,
    'ph': 'e',
    'id': '2',
    'args': {'isolateId': 'isolates/677008524697083'},
  }),
  testTraceEventWrapper({
    'name': 'ImageCache.putIfAbsent',
    'cat': 'Dart',
    'tid': 22019,
    'pid': 18510,
    'ts': 5294272706,
    'ph': 'e',
    'id': '1',
    'args': {'isolateId': 'isolates/677008524697083'},
  }),
];

final testTimelineJson = {
  'type': 'Timeline',
  'traceEvents': [
    {
      'name': 'thread_name',
      'ph': 'M',
      'tid': testUiThreadId,
      'args': {'name': '1.ui'},
    },
    {
      'name': 'thread_name',
      'ph': 'M',
      'tid': testRasterThreadId,
      'args': {'name': '1.raster'},
    },
    ...goldenTraceEventsJson,
  ],
  'timeOriginMicros': 193938741076,
  'timeExtentMicros': 193938770147 - 193938741076,
};

final namedThreadEventStartTrace = testTraceEventWrapper({
  'name': 'Shell::OnPlatformViewDispatchPointerDataPacket',
  'cat': 'Embedder',
  'tid': 775,
  'pid': 71358,
  'ts': 1011096130619,
  'ph': 'B',
  'args': {},
});

final namedThreadEventEndTrace = testTraceEventWrapper({
  'name': 'Shell::OnPlatformViewDispatchPointerDataPacket',
  'cat': 'Embedder',
  'tid': 775,
  'pid': 71358,
  'ts': 1011096130643,
  'ph': 'E',
  'args': {},
});

final eventForNamedThread = testSyncTimelineEvent(namedThreadEventStartTrace)
  ..addEndEvent(namedThreadEventEndTrace);
