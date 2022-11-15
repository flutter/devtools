// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/profiler/cpu_profile_model.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profile_transformer.dart';
import 'package:devtools_app/src/shared/profiler_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/test_data/cpu_profile.dart';

void main() {
  group('CpuProfileTransformer', () {
    late CpuProfileTransformer cpuProfileTransformer;
    late CpuProfileData cpuProfileData;

    setUp(() {
      cpuProfileTransformer = CpuProfileTransformer();
      cpuProfileData = CpuProfileData.parse(cpuProfileResponseJson);
    });

    test('processData', () async {
      expect(cpuProfileData.processed, isFalse);
      await cpuProfileTransformer.processData(
        cpuProfileData,
        processId: 'test',
      );
      expect(cpuProfileData.processed, isTrue);
      expect(
        cpuProfileData.cpuProfileRoot.profileAsString(),
        equals(goldenCpuProfileString),
      );
    });

    test('process response with missing leaf frame', () async {
      bool _runTest() {
        final cpuProfileDataWithMissingLeaf =
            CpuProfileData.parse(responseWithMissingLeafFrame);
        expect(
          () async {
            await cpuProfileTransformer.processData(
              cpuProfileDataWithMissingLeaf,
              processId: 'test',
            );
          },
          throwsA(const TypeMatcher<AssertionError>()),
        );
        return true;
      }

      // Only run this test if asserts are enabled.
      assert(_runTest());
    });

    test('dispose', () {
      cpuProfileTransformer.dispose();
      expect(
        () {
          cpuProfileTransformer.progressNotifier.addListener(() {});
        },
        throwsA(anything),
      );
    });
  });

  group('BottomUpTransformer', () {
    late BottomUpTransformer<CpuStackFrame> transformer;

    setUp(() {
      transformer = BottomUpTransformer<CpuStackFrame>();
    });

    test('cascadeSampleCounts', () {
      void verifySampleCount(CpuStackFrame stackFrame, int targetCount) {
        expect(stackFrame.exclusiveSampleCount, equals(0));
        expect(stackFrame.inclusiveSampleCount, equals(0));
        for (CpuStackFrame child in stackFrame.children) {
          verifySampleCount(child, targetCount);
        }
      }

      final stackFrame = testStackFrame.deepCopy();
      transformer.cascadeSampleCounts(stackFrame);

      verifySampleCount(stackFrame, 0);
    });

    test('processData step by step', () {
      expect(
        testStackFrame.profileAsString(),
        equals(testStackFrameStringGolden),
      );
      final List<CpuStackFrame> bottomUpRoots =
          transformer.generateBottomUpRoots(
        node: testStackFrame,
        currentBottomUpRoot: null,
        bottomUpRoots: [],
      );

      // Verify the original stack frame was not modified.
      expect(
        testStackFrame.profileAsString(),
        equals(testStackFrameStringGolden),
      );

      expect(bottomUpRoots.length, equals(6));

      // Set the bottom up sample counts for the roots.
      bottomUpRoots.forEach(transformer.cascadeSampleCounts);

      final buf = StringBuffer();
      for (CpuStackFrame stackFrame in bottomUpRoots) {
        buf.writeln(stackFrame.profileAsString());
      }
      expect(buf.toString(), equals(bottomUpPreMergeGolden));

      // Merge the bottom up roots.
      mergeCpuProfileRoots(bottomUpRoots);

      expect(bottomUpRoots.length, equals(4));

      buf.clear();
      for (CpuStackFrame stackFrame in bottomUpRoots) {
        buf.writeln(stackFrame.profileAsString());
      }
      expect(buf.toString(), equals(bottomUpGolden));
    });

    test('bottomUpRootsFor', () {
      expect(
        testStackFrame.profileAsString(),
        equals(testStackFrameStringGolden),
      );
      final List<CpuStackFrame> bottomUpRoots = transformer.bottomUpRootsFor(
        topDownRoot: testStackFrame,
        mergeSamples: mergeCpuProfileRoots,
        rootedAtTags: false,
      );

      // Verify the original stack frame was not modified.
      expect(
        testStackFrame.profileAsString(),
        equals(testStackFrameStringGolden),
      );

      expect(bottomUpRoots.length, equals(4));

      final buf = StringBuffer();
      for (CpuStackFrame stackFrame in bottomUpRoots) {
        buf.writeln(stackFrame.profileAsString());
      }
      expect(buf.toString(), equals(bottomUpGolden));
    });

    test('bottomUpRootsFor rootedAtTags', () {
      expect(
        testTagRootedStackFrame.profileAsString(),
        equals(testTagRootedStackFrameStringGolden),
      );

      // Note: this needs to be rooted at a root frame before transforming as
      // a tree rooted at a root frame is what is provided in cpu_profile_model.dart.
      final List<CpuStackFrame> bottomUpRoots = transformer.bottomUpRootsFor(
        topDownRoot: CpuStackFrame.root(zeroProfileMetaData)
          ..addChild(testTagRootedStackFrame),
        mergeSamples: mergeCpuProfileRoots,
        rootedAtTags: true,
      );

      // Verify the original stack frame was not modified.
      expect(
        testTagRootedStackFrame.profileAsString(),
        equals(testTagRootedStackFrameStringGolden),
      );

      expect(bottomUpRoots.length, equals(1));

      final buf = StringBuffer();
      for (CpuStackFrame stackFrame in bottomUpRoots) {
        buf.writeln(stackFrame.profileAsString());
      }
      expect(buf.toString(), equals(tagRootedBottomUpGolden));
    });
  });
}
