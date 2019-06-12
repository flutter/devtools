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
    test('sampleCount', () {
      expect(testStackFrame.inclusiveSampleCount, equals(10));
    });

    test('totalTime and selfTime', () {
      expect(testStackFrame.totalTimeRatio, equals(1.0));
      expect(testStackFrame.totalTime.inMicroseconds, equals(100));
      expect(testStackFrame.selfTimeRatio, equals(0.0));
      expect(testStackFrame.selfTime.inMicroseconds, equals(0));

      expect(stackFrame_2.totalTimeRatio, equals(0.3));
      expect(stackFrame_2.totalTime.inMicroseconds, equals(30));
      expect(stackFrame_2.selfTimeRatio, equals(0.3));
      expect(stackFrame_2.selfTime.inMicroseconds, equals(30));

      expect(stackFrame_3.totalTimeRatio, equals(0.7));
      expect(stackFrame_3.totalTime.inMicroseconds, equals(70));
      expect(stackFrame_3.selfTimeRatio, equals(0.2));
      expect(stackFrame_3.selfTime.inMicroseconds, equals(20));

      expect(stackFrame_5.totalTimeRatio, equals(0.4));
      expect(stackFrame_5.totalTime.inMicroseconds, equals(40));
      expect(stackFrame_5.selfTimeRatio, equals(0.4));
      expect(stackFrame_5.selfTime.inMicroseconds, equals(40));
    });
  });
}

final TimeRange profileTime = TimeRange()
  ..start = const Duration(microseconds: 0)
  ..end = const Duration(microseconds: 100);
final CpuStackFrame stackFrame_0 = CpuStackFrame(
  id: 'id_0',
  name: '0',
  category: 'Dart',
  url: '',
  profileTime: profileTime,
)..exclusiveSampleCount = 0;
final CpuStackFrame stackFrame_1 = CpuStackFrame(
  id: 'id_1',
  name: '1',
  category: 'Dart',
  url: 'org-dartlang-sdk:///third_party/dart/sdk/lib/async/zone.dart',
  profileTime: profileTime,
)..exclusiveSampleCount = 0;
final CpuStackFrame stackFrame_2 = CpuStackFrame(
  id: 'id_2',
  name: '2',
  category: 'Dart',
  url: 'file:///path/to/flutter/packages/flutter/lib/src/widgets/binding.dart',
  profileTime: profileTime,
)..exclusiveSampleCount = 3;
final CpuStackFrame stackFrame_3 = CpuStackFrame(
  id: 'id_3',
  name: '3',
  category: 'Dart',
  url: 'url',
  profileTime: profileTime,
)..exclusiveSampleCount = 2;
final CpuStackFrame stackFrame_4 = CpuStackFrame(
  id: 'id_4',
  name: '4',
  category: 'Dart',
  url: 'url',
  profileTime: profileTime,
)..exclusiveSampleCount = 1;
final CpuStackFrame stackFrame_5 = CpuStackFrame(
  id: 'id_5',
  name: '5',
  category: 'Dart',
  url: 'url',
  profileTime: profileTime,
)..exclusiveSampleCount = 4;

final CpuStackFrame testStackFrame = stackFrame_0
  ..addChild(stackFrame_1
    ..addChild(stackFrame_2)
    ..addChild(stackFrame_3..addChild(stackFrame_4)..addChild(stackFrame_5)));
