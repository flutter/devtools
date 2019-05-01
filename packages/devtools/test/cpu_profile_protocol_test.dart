// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:devtools/src/timeline/cpu_profile_protocol.dart';
import 'package:test/test.dart';
import 'package:vm_service_lib/vm_service_lib.dart' show Response;

void main() {
  CpuProfileData cpuProfileData;

  setUp(() {
    cpuProfileData = CpuProfileData(
      sampleResponse,
      const Duration(milliseconds: 10), // 10 is arbitrary.
    );
  });

  group('CpuProfileData', () {
    test('processCpuProfile', () {
      expect(cpuProfileData.sampleCount, equals(4));
      expect(
        cpuProfileData.cpuProfileRoot.toStringDeep(),
        equals(goldenCpuProfile),
      );
    });
  });

  group('CpuStackFrame', () {
    test('depth', () {
      expect(testStackFrame.depth, equals(4));
      expect(cpuProfileData.cpuProfileRoot.depth, equals(7));
    });

    test('sampleCount', () {
      expect(testStackFrame.sampleCount, equals(3));
      expect(cpuProfileData.cpuProfileRoot.sampleCount, equals(4));
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
      );
      final child = CpuStackFrame(
        id: 'id_1',
        name: 'child',
        category: 'Dart',
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
);
final CpuStackFrame stackFrame_1 = CpuStackFrame(
  id: 'id_1',
  name: '1',
  category: 'Dart',
);
final CpuStackFrame stackFrame_2 = CpuStackFrame(
  id: 'id_2',
  name: '2',
  category: 'Dart',
);
final CpuStackFrame stackFrame_3 = CpuStackFrame(
  id: 'id_3',
  name: '3',
  category: 'Dart',
);
final CpuStackFrame stackFrame_4 = CpuStackFrame(
  id: 'id_4',
  name: '4',
  category: 'Dart',
);
final CpuStackFrame stackFrame_5 = CpuStackFrame(
  id: 'id_5',
  name: '5',
  category: 'Dart',
);

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
  cpuProfile - children: 2
    140357727781376-1 - children: 1
      140357727781376-2 - children: 1
        140357727781376-3 - children: 2
          140357727781376-4 - children: 1
            140357727781376-5 - children: 0
          140357727781376-6 - children: 1
            140357727781376-7 - children: 1
              140357727781376-8 - children: 0
    140357727781376-9 - children: 2
      140357727781376-10 - children: 1
        140357727781376-11 - children: 0
      140357727781376-12 - children: 1
        140357727781376-13 - children: 1
          140357727781376-14 - children: 0
''';

final sampleResponse = Response.parse({
  'type': '_CpuProfileTimeline',
  'samplePeriod': 1000,
  'stackDepth': 128,
  'sampleCount': 4,
  'timeSpan': 0.003678,
  'timeOriginMicros': 47377796685,
  'timeExtentMicros': 3678,
  // Root of new sample.
  'stackFrames': {
    '140357727781376-1': {
      'category': 'Dart',
      'name': 'thread_start',
    },
    '140357727781376-2': {
      'category': 'Dart',
      'name': '_pthread_start',
      'parent': '140357727781376-1',
    },
    '140357727781376-3': {
      'category': 'Dart',
      'name': '_WidgetsFlutterBinding&BindingBase',
      'parent': '140357727781376-2',
    },
    '140357727781376-4': {
      'category': 'Dart',
      'name': 'BuildOwner.buildScope',
      'parent': '140357727781376-3',
    },
    '140357727781376-5': {
      'category': 'Dart',
      'name': 'Element.rebuild',
      'parent': '140357727781376-4',
    },
    // Branches off to different sample.
    '140357727781376-6': {
      'category': 'Dart',
      'name': 'BuildOwner.finalizeTree',
      'parent': '140357727781376-3',
    },
    '140357727781376-7': {
      'category': 'Dart',
      'name': 'Timeline.finishSync',
      'parent': '140357727781376-6',
    },
    '140357727781376-8': {
      'category': 'Dart',
      'name': '_SyncBlock.finish',
      'parent': '140357727781376-7',
    },
    // Root of new sample.
    '140357727781376-9': {
      'category': 'Dart',
      'name': '[Truncated]',
    },
    '140357727781376-10': {
      'category': 'Dart',
      'name': 'RenderObject._getSemanticsForParent.<anonymous closure>',
      'parent': '140357727781376-9',
    },
    '140357727781376-11': {
      'category': 'Dart',
      'name': 'RenderObject._getSemanticsForParent',
      'parent': '140357727781376-10',
    },
    // Branches off to different sample.
    '140357727781376-12': {
      'category': 'Dart',
      'name': '_WidgetsFlutterBinding&BindingBase_handleDrawFrame',
      'parent': '140357727781376-9',
    },
    '140357727781376-13': {
      'category': 'Dart',
      'name': '_WidgetsFlutterBinding&BindingBase&Gesture.handleDrawFrame',
      'parent': '140357727781376-12',
    },
    '140357727781376-14': {
      'category': 'Dart',
      'name': '_WidgetsFlutterBinding&BindingBase&Gesture._invokeFrameCallback',
      'parent': '140357727781376-13',
    }
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
    }
  ]
});
