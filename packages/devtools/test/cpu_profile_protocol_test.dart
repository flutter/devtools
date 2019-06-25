// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:devtools/src/timeline/cpu_profile_model.dart';
import 'package:devtools/src/timeline/cpu_profile_protocol.dart';
import 'package:test/test.dart';

import 'support/cpu_profile_test_data.dart';

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
        equals(goldenCpuProfileString),
      );
    });

    test('process response with missing leaf frame', () async {
      bool _runTest() {
        final cpuProfileDataWithMissingLeaf =
            CpuProfileData.parse(responseWithMissingLeafFrame);
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
  });

  group('BottomUpProfileProcessor', () {
    final bottomUpProtocol = BottomUpProfileProcessor();

    test('setBottomUpSampleCounts', () {
      void verifySampleCount(CpuStackFrame stackFrame, int targetCount) {
        expect(stackFrame.exclusiveSampleCount, equals(0));
        expect(stackFrame.inclusiveSampleCount, equals(0));
        for (CpuStackFrame child in stackFrame.children) {
          verifySampleCount(child, targetCount);
        }
      }

      final stackFrame = testStackFrame.deepCopy();
      bottomUpProtocol.cascadeSampleCounts(stackFrame);

      verifySampleCount(stackFrame, 0);
    });

    test('processData step by step', () {
      expect(testStackFrame.toStringDeep(), equals(testStackFrameStringGolden));
      final List<CpuStackFrame> bottomUpRoots =
          bottomUpProtocol.getRoots(testStackFrame, null, []);

      // Verify the original stack frame was not modified.
      expect(testStackFrame.toStringDeep(), equals(testStackFrameStringGolden));

      expect(bottomUpRoots.length, equals(6));

      // Set the bottom up sample counts for the roots.
      bottomUpRoots.forEach(bottomUpProtocol.cascadeSampleCounts);

      final buf = StringBuffer();
      for (CpuStackFrame stackFrame in bottomUpRoots) {
        buf.writeln(stackFrame.toStringDeep());
      }
      expect(buf.toString(), equals(bottomUpPreMergeGolden));

      // Merge the bottom up roots.
      bottomUpProtocol.mergeRoots(bottomUpRoots);

      expect(bottomUpRoots.length, equals(4));

      buf.clear();
      for (CpuStackFrame stackFrame in bottomUpRoots) {
        buf.writeln(stackFrame.toStringDeep());
      }
      expect(buf.toString(), equals(bottomUpGolden));
    });

    test('processData', () {
      expect(testStackFrame.toStringDeep(), equals(testStackFrameStringGolden));
      final List<CpuStackFrame> bottomUpRoots =
          bottomUpProtocol.processData(testStackFrame);

      // Verify the original stack frame was not modified.
      expect(testStackFrame.toStringDeep(), equals(testStackFrameStringGolden));

      expect(bottomUpRoots.length, equals(4));

      final buf = StringBuffer();
      for (CpuStackFrame stackFrame in bottomUpRoots) {
        buf.writeln(stackFrame.toStringDeep());
      }
      expect(buf.toString(), equals(bottomUpGolden));
    });
  });
}
