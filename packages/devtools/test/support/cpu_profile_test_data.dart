// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:devtools/src/timeline/cpu_profile_model.dart';
import 'package:devtools/src/utils.dart';

final Map<String, dynamic> goldenCpuProfileDataJson = {
  'type': '_CpuProfileTimeline',
  'samplePeriod': 50,
  'sampleCount': 8,
  'timeOriginMicros': 47377796685,
  'timeExtentMicros': 3000,
  'stackFrames': goldenCpuProfileStackFrames,
  'traceEvents': goldenCpuProfileTraceEvents,
};

const goldenCpuProfileString = '''
  all - children: 2 - excl: 0 - incl: 8
    thread_start - children: 1 - excl: 0 - incl: 2
      _pthread_start - children: 1 - excl: 0 - incl: 2
        _drawFrame - children: 2 - excl: 0 - incl: 2
          _WidgetsFlutterBinding.draw - children: 1 - excl: 0 - incl: 1
            RendererBinding.drawFrame - children: 0 - excl: 1 - incl: 1
          _RenderProxyBox.paint - children: 1 - excl: 0 - incl: 1
            PaintingContext.paintChild - children: 1 - excl: 0 - incl: 1
              _SyncBlock.finish - children: 0 - excl: 1 - incl: 1
    [Truncated] - children: 2 - excl: 0 - incl: 6
      RenderObject._getSemanticsForParent.<closure> - children: 1 - excl: 0 - incl: 1
        RenderObject._getSemanticsForParent - children: 0 - excl: 1 - incl: 1
      RenderPhysicalModel.paint - children: 1 - excl: 0 - incl: 5
        RenderCustomMultiChildLayoutBox.paint - children: 1 - excl: 0 - incl: 5
          _RenderCustomMultiChildLayoutBox.defaultPaint - children: 2 - excl: 3 - incl: 5
            RenderObject._paintWithContext - children: 0 - excl: 1 - incl: 1
            RenderStack.paintStack - children: 1 - excl: 0 - incl: 1
              Gesture._invokeFrameCallback - children: 0 - excl: 1 - incl: 1
''';

final Map<String, dynamic> cpuProfileResponseJson = {
  'type': '_CpuProfileTimeline',
  'samplePeriod': 50,
  'stackDepth': 128,
  'sampleCount': 8,
  'timeSpan': 0.003678,
  'timeOriginMicros': 47377796685,
  'timeExtentMicros': 3000,
  'stackFrames': goldenCpuProfileStackFrames,
  'traceEvents': goldenCpuProfileTraceEvents,
};

final Map<String, dynamic> goldenCpuProfileStackFrames =
    Map.from(subProfileStackFrames)
      ..addAll({
        '140357727781376-12': {
          'category': 'Dart',
          'name': 'RenderPhysicalModel.paint',
          'parent': '140357727781376-9',
          'resolvedUrl':
              'path/to/flutter/packages/flutter/lib/src/rendering/proxy_box.dart',
        },
        '140357727781376-13': {
          'category': 'Dart',
          'name': 'RenderCustomMultiChildLayoutBox.paint',
          'parent': '140357727781376-12',
          'resolvedUrl':
              'path/to/flutter/packages/flutter/lib/src/rendering/custom_layout.dart',
        },
        '140357727781376-14': {
          'category': 'Dart',
          'name': '_RenderCustomMultiChildLayoutBox.defaultPaint',
          'parent': '140357727781376-13',
          'resolvedUrl':
              'path/to/flutter/packages/flutter/lib/src/rendering/box.dart',
        },
        '140357727781376-15': {
          'category': 'Dart',
          'name': 'RenderObject._paintWithContext',
          'parent': '140357727781376-14',
          'resolvedUrl':
              'path/to/flutter/packages/flutter/lib/src/rendering/object.dart',
        },
        '140357727781376-16': {
          'category': 'Dart',
          'name': 'RenderStack.paintStack',
          'parent': '140357727781376-14',
          'resolvedUrl':
              'path/to/flutter/packages/flutter/lib/src/rendering/stack.dart',
        },
        '140357727781376-17': {
          'category': '[Stub] OneArgCheckInlineCache',
          'name':
              '_WidgetsFlutterBinding&BindingBase&Gesture._invokeFrameCallback',
          'parent': '140357727781376-16',
          'resolvedUrl': '',
        }
      });

final subProfileStackFrames = {
  '140357727781376-1': {
    'category': 'Dart',
    'name': 'thread_start',
    'resolvedUrl': '',
  },
  '140357727781376-2': {
    'category': 'Dart',
    'name': '_pthread_start',
    'parent': '140357727781376-1',
    'resolvedUrl': '',
  },
  '140357727781376-3': {
    'category': 'Dart',
    'name': '_drawFrame',
    'parent': '140357727781376-2',
    'resolvedUrl': 'org-dartlang-sdk:///flutter/lib/ui/hooks.dart',
  },
  '140357727781376-4': {
    'category': 'Dart',
    'name': '_WidgetsFlutterBinding.draw',
    'parent': '140357727781376-3',
    'resolvedUrl':
        'file:///path/to/flutter/packages/flutter/lib/src/scheduler/binding.dart',
  },
  '140357727781376-5': {
    'category': 'Dart',
    'name': 'RendererBinding.drawFrame',
    'parent': '140357727781376-4',
    'resolvedUrl':
        'path/to/flutter/packages/flutter/lib/src/widgets/binding.dart',
  },
  '140357727781376-6': {
    'category': 'Dart',
    'name': '_RenderProxyBox.paint',
    'parent': '140357727781376-3',
    'resolvedUrl':
        'path/to/flutter/packages/flutter/lib/src/rendering/proxy_box.dart',
  },
  '140357727781376-7': {
    'category': 'Dart',
    'name': 'PaintingContext.paintChild',
    'parent': '140357727781376-6',
    'resolvedUrl':
        'path/to/flutter/packages/flutter/lib/src/rendering/object.dart',
  },
  '140357727781376-8': {
    'category': 'Dart',
    'name': '_SyncBlock.finish',
    'parent': '140357727781376-7',
    'resolvedUrl': '',
  },
  '140357727781376-9': {
    'category': 'Dart',
    'name': '[Truncated]',
    'resolvedUrl': '',
  },
  '140357727781376-10': {
    'category': 'Dart',
    'name': 'RenderObject._getSemanticsForParent.<closure>',
    'parent': '140357727781376-9',
    'resolvedUrl':
        'file:///path/to/flutter/packages/flutter/lib/src/rendering/object.dart',
  },
  '140357727781376-11': {
    'category': 'Dart',
    'name': 'RenderObject._getSemanticsForParent',
    'parent': '140357727781376-10',
    'resolvedUrl':
        'file:///path/to/flutter/packages/flutter/lib/src/rendering/object.dart',
  },
};

final List<Map<String, dynamic>> goldenCpuProfileTraceEvents =
    List.from(subProfileTraceEvents)
      ..addAll([
        {
          'ph': 'P',
          'name': '',
          'pid': 77616,
          'tid': 42247,
          'ts': 47377800363,
          'cat': 'Dart',
          'args': {'mode': 'basic'},
          'sf': '140357727781376-14'
        },
        {
          'ph': 'P',
          'name': '',
          'pid': 77616,
          'tid': 42247,
          'ts': 47377800463,
          'cat': 'Dart',
          'args': {'mode': 'basic'},
          'sf': '140357727781376-14'
        },
        {
          'ph': 'P',
          'name': '',
          'pid': 77616,
          'tid': 42247,
          'ts': 47377800563,
          'cat': 'Dart',
          'args': {'mode': 'basic'},
          'sf': '140357727781376-14'
        },
        {
          'ph': 'P',
          'name': '',
          'pid': 77616,
          'tid': 42247,
          'ts': 47377800663,
          'cat': 'Dart',
          'args': {'mode': 'basic'},
          'sf': '140357727781376-15'
        },
        {
          'ph': 'P',
          'name': '',
          'pid': 77616,
          'tid': 42247,
          'ts': 47377800763,
          'cat': 'Dart',
          'args': {'mode': 'basic'},
          'sf': '140357727781376-17'
        }
      ]);

final subProfileTraceEvents = [
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377796685,
    'cat': 'Dart',
    'args': {'mode': 'basic'},
    'sf': '140357727781376-5'
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377797975,
    'cat': 'Dart',
    'args': {'mode': 'basic'},
    'sf': '140357727781376-8'
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377799063,
    'cat': 'Dart',
    'args': {'mode': 'basic'},
    'sf': '140357727781376-11'
  },
];

final responseWithMissingLeafFrame = {
  'type': '_CpuProfileTimeline',
  'samplePeriod': 1000,
  'stackDepth': 128,
  'sampleCount': 3,
  'timeSpan': 0.003678,
  'timeOriginMicros': 47377796685,
  'timeExtentMicros': 3678,
  'stackFrames': {
    // Missing stack frame 140357727781376-0
    '140357727781376-1': {
      'category': 'Dart',
      'name': 'thread_start',
      'resolvedUrl': '',
    },
    '140357727781376-2': {
      'category': 'Dart',
      'name': '_pthread_start',
      'parent': '140357727781376-1',
      'resolvedUrl': '',
    },
    '140357727781376-3': {
      'category': 'Dart',
      'name': '_drawFrame',
      'parent': '140357727781376-2',
      'resolvedUrl': 'org-dartlang-sdk:///flutter/lib/ui/hooks.dart',
    },
    '140357727781376-4': {
      'category': 'Dart',
      'name': '_WidgetsFlutterBinding&BindingBase',
      'parent': '140357727781376-3',
      'resolvedUrl':
          'file:///path/to/flutter/packages/flutter/lib/src/scheduler/binding.dart',
    },
  },
  'traceEvents': [
    {
      'ph': 'P',
      'name': '',
      'pid': 77616,
      'tid': 42247,
      'ts': 47377796685,
      'cat': 'Dart',
      'args': {'mode': 'basic'},
      'sf': '140357727781376-0'
    },
    {
      'ph': 'P',
      'name': '',
      'pid': 77616,
      'tid': 42247,
      'ts': 47377797975,
      'cat': 'Dart',
      'args': {'mode': 'basic'},
      'sf': '140357727781376-2'
    },
    {
      'ph': 'P',
      'name': '',
      'pid': 77616,
      'tid': 42247,
      'ts': 47377799063,
      'cat': 'Dart',
      'args': {'mode': 'basic'},
      'sf': '140357727781376-4'
    },
  ]
};

final TimeRange profileTime = TimeRange()
  ..start = const Duration(microseconds: 0)
  ..end = const Duration(microseconds: 100);

final CpuStackFrame stackFrameA = CpuStackFrame(
  id: 'id_0',
  name: 'A',
  category: 'Dart',
  url: '',
  profileTime: profileTime,
  profileSampleCount: 10,
)..exclusiveSampleCount = 0;

final CpuStackFrame stackFrameB = CpuStackFrame(
  id: 'id_1',
  name: 'B',
  category: 'Dart',
  url: 'org-dartlang-sdk:///third_party/dart/sdk/lib/async/zone.dart',
  profileTime: profileTime,
  profileSampleCount: 10,
)..exclusiveSampleCount = 0;

final CpuStackFrame stackFrameC = CpuStackFrame(
  id: 'id_2',
  name: 'C',
  category: 'Dart',
  url: 'file:///path/to/flutter/packages/flutter/lib/src/widgets/binding.dart',
  profileTime: profileTime,
  profileSampleCount: 10,
)..exclusiveSampleCount = 2;
final CpuStackFrame stackFrameD = CpuStackFrame(
  id: 'id_3',
  name: 'D',
  category: 'Dart',
  url: 'url',
  profileTime: profileTime,
  profileSampleCount: 10,
)..exclusiveSampleCount = 2;

final CpuStackFrame stackFrameE = CpuStackFrame(
  id: 'id_4',
  name: 'E',
  category: 'Dart',
  url: 'url',
  profileTime: profileTime,
  profileSampleCount: 10,
)..exclusiveSampleCount = 1;
final CpuStackFrame stackFrameF = CpuStackFrame(
  id: 'id_5',
  name: 'F',
  category: 'Dart',
  url: 'url',
  profileTime: profileTime,
  profileSampleCount: 10,
)..exclusiveSampleCount = 0;

final CpuStackFrame stackFrameF2 = CpuStackFrame(
  id: 'id_6',
  name: 'F',
  category: 'Dart',
  url: 'url',
  profileTime: profileTime,
  profileSampleCount: 10,
)..exclusiveSampleCount = 3;

final CpuStackFrame stackFrameC2 = CpuStackFrame(
  id: 'id_7',
  name: 'C',
  category: 'Dart',
  url: 'file:///path/to/flutter/packages/flutter/lib/src/widgets/binding.dart',
  profileTime: profileTime,
  profileSampleCount: 10,
)..exclusiveSampleCount = 1;

final CpuStackFrame stackFrameC3 = CpuStackFrame(
  id: 'id_8',
  name: 'C',
  category: 'Dart',
  url: 'file:///path/to/flutter/packages/flutter/lib/src/widgets/binding.dart',
  profileTime: profileTime,
  profileSampleCount: 10,
)..exclusiveSampleCount = 1;

final CpuStackFrame stackFrameG = CpuStackFrame(
  id: 'id_9',
  name: 'G',
  category: 'Dart',
  url: 'file:///path/to/flutter/packages/flutter/lib/src/widgets/binding.dart',
  profileTime: profileTime,
  profileSampleCount: 10,
)..exclusiveSampleCount = 1;

final CpuStackFrame testStackFrame = stackFrameA
  ..addChild(stackFrameB
    ..addChild(stackFrameC)
    ..addChild(stackFrameD
      ..addChild(stackFrameE..addChild(stackFrameF..addChild(stackFrameC2)))
      ..addChild(stackFrameF2..addChild(stackFrameC3))));

const String testStackFrameStringGolden = '''
  A - children: 1 - excl: 0 - incl: 10
    B - children: 2 - excl: 0 - incl: 10
      C - children: 0 - excl: 2 - incl: 2
      D - children: 2 - excl: 2 - incl: 8
        E - children: 1 - excl: 1 - incl: 2
          F - children: 1 - excl: 0 - incl: 1
            C - children: 0 - excl: 1 - incl: 1
        F - children: 1 - excl: 3 - incl: 4
          C - children: 0 - excl: 1 - incl: 1
''';

const String bottomUpPreMergeGolden = '''
  C - children: 1 - excl: 2 - incl: 2
    B - children: 1 - excl: 2 - incl: 2
      A - children: 0 - excl: 2 - incl: 2

  D - children: 1 - excl: 2 - incl: 2
    B - children: 1 - excl: 2 - incl: 2
      A - children: 0 - excl: 2 - incl: 2

  E - children: 1 - excl: 1 - incl: 1
    D - children: 1 - excl: 1 - incl: 1
      B - children: 1 - excl: 1 - incl: 1
        A - children: 0 - excl: 1 - incl: 1

  C - children: 1 - excl: 1 - incl: 1
    F - children: 1 - excl: 1 - incl: 1
      E - children: 1 - excl: 1 - incl: 1
        D - children: 1 - excl: 1 - incl: 1
          B - children: 1 - excl: 1 - incl: 1
            A - children: 0 - excl: 1 - incl: 1

  F - children: 1 - excl: 3 - incl: 3
    D - children: 1 - excl: 3 - incl: 3
      B - children: 1 - excl: 3 - incl: 3
        A - children: 0 - excl: 3 - incl: 3

  C - children: 1 - excl: 1 - incl: 1
    F - children: 1 - excl: 1 - incl: 1
      D - children: 1 - excl: 1 - incl: 1
        B - children: 1 - excl: 1 - incl: 1
          A - children: 0 - excl: 1 - incl: 1

''';

const String bottomUpGolden = '''
  C - children: 2 - excl: 4 - incl: 4
    B - children: 1 - excl: 2 - incl: 2
      A - children: 0 - excl: 2 - incl: 2
    F - children: 2 - excl: 2 - incl: 2
      E - children: 1 - excl: 1 - incl: 1
        D - children: 1 - excl: 1 - incl: 1
          B - children: 1 - excl: 1 - incl: 1
            A - children: 0 - excl: 1 - incl: 1
      D - children: 1 - excl: 1 - incl: 1
        B - children: 1 - excl: 1 - incl: 1
          A - children: 0 - excl: 1 - incl: 1

  D - children: 1 - excl: 2 - incl: 2
    B - children: 1 - excl: 2 - incl: 2
      A - children: 0 - excl: 2 - incl: 2

  E - children: 1 - excl: 1 - incl: 1
    D - children: 1 - excl: 1 - incl: 1
      B - children: 1 - excl: 1 - incl: 1
        A - children: 0 - excl: 1 - incl: 1

  F - children: 1 - excl: 3 - incl: 3
    D - children: 1 - excl: 3 - incl: 3
      B - children: 1 - excl: 3 - incl: 3
        A - children: 0 - excl: 3 - incl: 3

''';
