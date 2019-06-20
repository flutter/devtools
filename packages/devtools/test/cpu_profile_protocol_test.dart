// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:devtools/src/timeline/cpu_profile_model.dart';
import 'package:devtools/src/timeline/cpu_profile_protocol.dart';
import 'package:test/test.dart';

import 'support/timeline_test_data.dart';

void main() {
  group('CpuProfileProtocol', () {
    final cpuProfileProtocol = CpuProfileProtocol();
    final CpuProfileData cpuProfileData =
        CpuProfileData.parse(cpuProfileResponseJson);

    test('processCpuProfile', () {
      expect(cpuProfileData.processed, isFalse);
      cpuProfileProtocol.processData(cpuProfileData);
      expect(cpuProfileData.processed, isTrue);
      expect(
        cpuProfileData.cpuProfileRoot.toStringDeep(),
        equals(_goldenCpuProfile),
      );
    });

    test('process response with missing leaf frame', () async {
      bool _runTest() {
        final cpuProfileDataWithMissingLeaf =
            CpuProfileData.parse(_responseWithMissingLeafFrame);
        expect(
          () {
            cpuProfileProtocol.processData(cpuProfileDataWithMissingLeaf);
          },
          throwsA(const TypeMatcher<AssertionError>()),
        );
        return true;
      }

      // Only run this test if asserts are enabled.
      assert(_runTest());
    });

    test('getSimpleStackFrameName', () {
      // Ampersand and period cases.
      String name =
          '_WidgetsFlutterBinding&BindingBase&GestureBinding&ServicesBinding&'
          'SchedulerBinding.handleBeginFrame';
      expect(
        cpuProfileProtocol.getSimpleStackFrameName(name),
        equals('_WidgetsFlutterBinding.handleBeginFrame'),
      );

      name =
          '_WidgetsFlutterBinding&BindingBase&GestureBinding&ServicesBinding&'
          'SchedulerBinding.handleBeginFrame.<anonymous closure>';
      expect(
        cpuProfileProtocol.getSimpleStackFrameName(name),
        equals('_WidgetsFlutterBinding.handleBeginFrame.<anonymous closure>'),
      );

      name = '__CompactLinkedHashSet&_HashFieldBase&_HashBase&_OperatorEquals'
          'AndHashCode&SetMixin.toList';
      expect(
        cpuProfileProtocol.getSimpleStackFrameName(name),
        equals('__CompactLinkedHashSet.toList'),
      );

      // Ampersand and no period.
      name =
          'dart::DartEntry::InvokeFunction(dart::Function const&, dart::Array '
          'const&, dart::Array const&, unsigned long)';
      expect(cpuProfileProtocol.getSimpleStackFrameName(name), equals(name));

      // Period and no ampersand.
      name = '_CustomZone.run';
      expect(cpuProfileProtocol.getSimpleStackFrameName(name), equals(name));
    });
  });
}

const _goldenCpuProfile = '''
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

final _responseWithMissingLeafFrame = {
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
