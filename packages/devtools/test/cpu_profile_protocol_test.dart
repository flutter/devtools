// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:devtools/src/timeline/cpu_profile_protocol.dart';
import 'package:test/test.dart';
import 'package:vm_service_lib/vm_service_lib.dart' show Response;

void main() {
  final cpuProfileData = CpuProfileData(
    sampleResponse,
    const Duration(milliseconds: 10), // 10 is arbitrary.
  );

  group('CpuProfileData', () {
    test('processCpuProfile', () {
      expect(cpuProfileData.sampleCount, equals(8));
      expect(
        cpuProfileData.cpuProfileRoot.toStringDeep(),
        equals(goldenCpuProfile),
      );
    });

    test('process response with missing leaf frame', () async {
      bool _runTest() {
        expect(
          () {
            CpuProfileData(
              sampleResponseWithMissingLeafFrame,
              const Duration(milliseconds: 10), // 10 is arbitrary.
            );
          },
          // TODO(kenzie): replace with [isAssertionError] once
          // https://github.com/dart-lang/matcher/pull/112 lands and is available
          // in version of dart-lang/matcher we use.
          throwsA(const TypeMatcher<AssertionError>()),
        );
        return true;
      }

      // Only run this test if asserts are enabled.
      assert(_runTest());
    });
  });

  group('CpuStackFrame', () {
    test('depth', () {
      expect(testStackFrame.depth, equals(4));
      expect(cpuProfileData.cpuProfileRoot.depth, equals(7));
    });

    test('sampleCount', () {
      expect(testStackFrame.inclusiveSampleCount, equals(3));
      expect(cpuProfileData.cpuProfileRoot.inclusiveSampleCount, equals(8));
    });

    test('cpuConsumptionRatio', () {
      expect(stackFrame_3.cpuConsumptionRatio, equals(0.6666666666666666));
      expect(stackFrame_5.cpuConsumptionRatio, equals(0.3333333333333333));
    });

    test('add child', () {
      final parent = CpuStackFrame(
        id: 'id_0',
        name: 'parent',
        category: 'Dart',
        url: 'url',
      );
      final child = CpuStackFrame(
        id: 'id_1',
        name: 'child',
        category: 'Dart',
        url: 'url',
      );
      expect(parent.children, isEmpty);
      expect(child.parent, isNull);
      parent.addChild(child);
      expect(parent.children, isNotEmpty);
      expect(parent.children.first, equals(child));
      expect(child.parent, equals(parent));
    });

    test('getRoot', () {
      expect(
        stackFrame_2.getRoot().toStringDeep(),
        equals(testStackFrame.toStringDeep()),
      );
    });
  });
}

final CpuStackFrame stackFrame_0 = CpuStackFrame(
  id: 'id_0',
  name: '0',
  category: 'Dart',
  url: 'url',
)..exclusiveSampleCount = 0;
final CpuStackFrame stackFrame_1 = CpuStackFrame(
  id: 'id_1',
  name: '1',
  category: 'Dart',
  url: 'url',
)..exclusiveSampleCount = 0;
final CpuStackFrame stackFrame_2 = CpuStackFrame(
  id: 'id_2',
  name: '2',
  category: 'Dart',
  url: 'url',
)..exclusiveSampleCount = 1;
final CpuStackFrame stackFrame_3 = CpuStackFrame(
  id: 'id_3',
  name: '3',
  category: 'Dart',
  url: 'url',
)..exclusiveSampleCount = 0;
final CpuStackFrame stackFrame_4 = CpuStackFrame(
  id: 'id_4',
  name: '4',
  category: 'Dart',
  url: 'url',
)..exclusiveSampleCount = 1;
final CpuStackFrame stackFrame_5 = CpuStackFrame(
  id: 'id_5',
  name: '5',
  category: 'Dart',
  url: 'url',
)..exclusiveSampleCount = 1;

final testStackFrame = stackFrame_0
  ..children = [
    (stackFrame_1
      ..parent = stackFrame_0
      ..children = [
        (stackFrame_2..parent = stackFrame_1),
        (stackFrame_3
          ..parent = stackFrame_1
          ..children = [
            stackFrame_4..parent = stackFrame_3,
            stackFrame_5..parent = stackFrame_3
          ])
      ])
  ];

const goldenCpuProfile = '''
  cpuProfile - children: 2 - exclusiveSampleCount: 0
    140357727781376-1 - children: 1 - exclusiveSampleCount: 0
      140357727781376-2 - children: 1 - exclusiveSampleCount: 0
        140357727781376-3 - children: 2 - exclusiveSampleCount: 0
          140357727781376-4 - children: 1 - exclusiveSampleCount: 0
            140357727781376-5 - children: 0 - exclusiveSampleCount: 1
          140357727781376-6 - children: 1 - exclusiveSampleCount: 0
            140357727781376-7 - children: 1 - exclusiveSampleCount: 0
              140357727781376-8 - children: 0 - exclusiveSampleCount: 1
    140357727781376-9 - children: 2 - exclusiveSampleCount: 0
      140357727781376-10 - children: 1 - exclusiveSampleCount: 0
        140357727781376-11 - children: 0 - exclusiveSampleCount: 1
      140357727781376-12 - children: 1 - exclusiveSampleCount: 0
        140357727781376-13 - children: 1 - exclusiveSampleCount: 0
          140357727781376-14 - children: 2 - exclusiveSampleCount: 3
            140357727781376-15 - children: 0 - exclusiveSampleCount: 1
            140357727781376-16 - children: 1 - exclusiveSampleCount: 0
              140357727781376-17 - children: 0 - exclusiveSampleCount: 1
''';

final sampleResponse = Response.parse({
  'type': '_CpuProfileTimeline',
  'samplePeriod': 1000,
  'stackDepth': 128,
  'sampleCount': 8,
  'timeSpan': 0.003678,
  'timeOriginMicros': 47377796685,
  'timeExtentMicros': 3678,
  'stackFrames': {
    // Root of new sample.
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
    // Branches off to different sample.
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
    // Root of new sample.
    '140357727781376-9': {
      'category': 'Dart',
      'name': '[Truncated]',
      'resolvedUrl': '',
    },
    '140357727781376-10': {
      'category': 'Dart',
      'name': 'RenderObject._getSemanticsForParent.<anonymous closure>',
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
    // Branches off to different sample.
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
      'name': '_WidgetsFlutterBinding&BindingBase&Gesture._invokeFrameCallback',
      'parent': '140357727781376-16',
      'resolvedUrl': '',
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
  ]
});

final sampleResponseWithMissingLeafFrame = Response.parse({
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
});
