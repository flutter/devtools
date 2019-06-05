// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:devtools/src/timeline/cpu_profile_model.dart';
import 'package:devtools/src/utils.dart';
import 'package:test/test.dart';

import 'support/timeline_test_data.dart';

void main() {
  group('CpuProfileData', () {
    final cpuProfileData = CpuProfileData.parse(cpuProfileResponseJson);

    test('init from parse', () {
      expect(
        cpuProfileData.stackFramesJson,
        equals(goldenCpuProfileStackFrames),
      );
      expect(
        cpuProfileData.stackTraceEvents,
        equals(goldenCpuProfileTraceEvents),
      );
      expect(cpuProfileData.sampleCount, equals(8));
      expect(cpuProfileData.samplePeriod, equals(50));
      expect(cpuProfileData.time.start.inMicroseconds, equals(47377796685));
      expect(cpuProfileData.time.end.inMicroseconds, equals(47377799685));
    });

    test('subProfile', () {
      final subProfile = CpuProfileData.subProfile(
          cpuProfileData,
          TimeRange()
            ..start = const Duration(microseconds: 47377796685)
            ..end = const Duration(microseconds: 47377799063));

      expect(
        subProfile.stackFramesJson,
        equals(subProfileStackFrames),
      );
      expect(
        subProfile.stackTraceEvents,
        equals(subProfileTraceEvents),
      );
      expect(subProfile.sampleCount, equals(3));
      expect(subProfile.samplePeriod, equals(cpuProfileData.samplePeriod));
    });

    test('to json', () {
      expect(cpuProfileData.json, equals(goldenCpuProfileDataJson));
    });
  });

  group('CpuStackFrame', () {
    test('depth', () {
      expect(testStackFrame.depth, equals(4));
    });

    test('sampleCount', () {
      expect(testStackFrame.inclusiveSampleCount, equals(3));
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

final CpuStackFrame testStackFrame = stackFrame_0
  ..addChild(stackFrame_1
    ..addChild(stackFrame_2)
    ..addChild(stackFrame_3..addChild(stackFrame_4)..addChild(stackFrame_5)));
