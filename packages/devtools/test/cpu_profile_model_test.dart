// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:devtools/src/profiler/cpu_profile_model.dart';
import 'package:devtools/src/utils.dart';
import 'package:test/test.dart';

import 'support/cpu_profile_test_data.dart';

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

    test('stackFrameIdCompare', () {
      // iOS
      String idA = '140225212960768-2';
      String idB = '140225212960768-10';
      expect(idA.compareTo(idB), equals(1));
      expect(stackFrameIdCompare(idA, idB), equals(-1));

      // Android
      idA = '-784070656-2';
      idB = '-784070656-10';
      expect(idA.compareTo(idB), equals(1));
      expect(stackFrameIdCompare(idA, idB), equals(-1));
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

      expect(stackFrameC.totalTimeRatio, equals(0.2));
      expect(stackFrameC.totalTime.inMicroseconds, equals(20));
      expect(stackFrameC.selfTimeRatio, equals(0.2));
      expect(stackFrameC.selfTime.inMicroseconds, equals(20));

      expect(stackFrameD.totalTimeRatio, equals(0.8));
      expect(stackFrameD.totalTime.inMicroseconds, equals(80));
      expect(stackFrameD.selfTimeRatio, equals(0.2));
      expect(stackFrameD.selfTime.inMicroseconds, equals(20));

      expect(stackFrameF.totalTimeRatio, equals(0.1));
      expect(stackFrameF.totalTime.inMicroseconds, equals(10));
      expect(stackFrameF.selfTimeRatio, equals(0.0));
      expect(stackFrameF.selfTime.inMicroseconds, equals(0));
    });

    test('shallowCopy', () {
      expect(stackFrameD.children.length, equals(2));
      expect(stackFrameD.parent, equals(stackFrameB));
      CpuStackFrame copy = stackFrameD.shallowCopy();
      expect(copy.children, isEmpty);
      expect(copy.parent, isNull);
      expect(
        copy.exclusiveSampleCount,
        equals(stackFrameD.exclusiveSampleCount),
      );
      expect(
        copy.inclusiveSampleCount,
        equals(stackFrameD.inclusiveSampleCount),
      );

      expect(stackFrameD.children.length, equals(2));
      expect(stackFrameD.parent, equals(stackFrameB));
      copy = stackFrameD.shallowCopy(resetInclusiveSampleCount: true);
      expect(copy.children, isEmpty);
      expect(copy.parent, isNull);
      expect(
        copy.exclusiveSampleCount,
        equals(stackFrameD.exclusiveSampleCount),
      );
      expect(copy.inclusiveSampleCount, copy.exclusiveSampleCount);
    });

    test('deepCopy', () {
      expect(testStackFrame.isExpanded, isFalse);
      expect(testStackFrame.children.length, equals(1));
      testStackFrame.isExpanded = true;
      expect(testStackFrame.isExpanded, isTrue);

      final copy = testStackFrame.deepCopy();
      expect(copy.isExpanded, isFalse);
      expect(copy.children.length, equals(1));
      for (CpuStackFrame child in copy.children) {
        expect(child.parent, equals(copy));
      }
      copy.addChild(stackFrameG);
      expect(copy.children.length, equals(2));
      expect(testStackFrame.children.length, equals(1));

      final copyFromMidTree = stackFrameC.deepCopy();
      expect(stackFrameC.parent, isNotNull);
      expect(stackFrameC.level, equals(2));
      expect(copyFromMidTree.parent, isNull);
      expect(copyFromMidTree.level, equals(0));
    });
  });

  test('matches', () {
    expect(stackFrameC.matches(stackFrameC2), isTrue);
    expect(stackFrameC.matches(stackFrameG), isFalse);
  });
}
