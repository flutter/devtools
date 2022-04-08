// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_redundant_argument_values, import_of_legacy_library_into_null_safe

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import 'test_data/cpu_profile_test_data.dart';

void main() {
  group('CpuProfileData', () {
    final cpuProfileData = CpuProfileData.parse(cpuProfileResponseJson);
    final cpuSamples = CpuSamples.parse(goldenSamplesJson)!;

    test('init from parse', () {
      expect(
        cpuProfileData.stackFramesJson,
        equals(goldenCpuProfileStackFrames),
      );
      expect(
        cpuProfileData.cpuSamples.map((sample) => sample.json),
        equals(goldenCpuProfileTraceEvents),
      );
      expect(cpuProfileData.profileMetaData.sampleCount, equals(8));
      expect(cpuProfileData.profileMetaData.samplePeriod, equals(50));
      expect(
        cpuProfileData.profileMetaData.time!.start!.inMicroseconds,
        equals(47377796685),
      );
      expect(
        cpuProfileData.profileMetaData.time!.end!.inMicroseconds,
        equals(47377799685),
      );
    });

    group('generateFromCpuSamples', () {
      ServiceConnectionManager manager;
      final service = MockVmService();
      setUp(() {
        when(service.onDebugEvent).thenAnswer((_) {
          return const Stream.empty();
        });
        when(service.onVMEvent).thenAnswer((_) {
          return const Stream.empty();
        });
        when(service.onIsolateEvent).thenAnswer((_) {
          return const Stream.empty();
        });
        when(service.onStdoutEvent).thenAnswer((_) {
          return const Stream.empty();
        });
        when(service.onStderrEvent).thenAnswer((_) {
          return const Stream.empty();
        });
        manager = FakeServiceManager(service: service);
        setGlobal(ServiceConnectionManager, manager);
      });

      // TODO: test that cpusamples generates cpupd?
      // TODO: re-enable and test the generation is done correctly
      //   test('basic test', () async {
      //     final samples = CpuSamples.parse(goldenSamplesJson);
      //     const isolateId = 'theIsolateId';
      //     const origin = 123;
      //     const extent = 456;
      //     final frameTemplate = {
      //       'name': '_startConnect',
      //       'category': 'Dart',
      //       'resolvedUrl':
      //           'org-dartlang-sdk:///third_party/dart/sdk/lib/_internal/vm/bin/socket_patch.dart',
      //     };

      //     final stackFrames = {
      //       '$isolateId-1': Map<String, String>.from(frameTemplate),
      //       '$isolateId-2': Map<String, String>.from(frameTemplate),
      //       '$isolateId-3': Map<String, String>.from(frameTemplate),
      //       '$isolateId-4': Map<String, String>.from(frameTemplate),
      //     };
      //     stackFrames['$isolateId-1']!['parent'] = 'cpuProfileRoot';
      //     stackFrames['$isolateId-2']!['parent'] = '$isolateId-1';
      //     stackFrames['$isolateId-3']!['parent'] = '$isolateId-2';
      //     stackFrames['$isolateId-4']!['parent'] = '$isolateId-3';
      //     final expectedCpuProfileTimeline = {
      //       'type': '_CpuProfileTimeline',
      //       'samplePeriod': samples!.samplePeriod,
      //       'sampleCount': samples.sampleCount,
      //       'stackDepth': samples.maxStackDepth,
      //       'timeOriginMicros': samples.timeOriginMicros,
      //       'timeExtentMicros': samples.timeExtentMicros,
      //       'stackFrames': stackFrames,
      //       'traceEvents': [
      //         {
      //           'ph': 'P',
      //           'name': '',
      //           'pid': samples.pid,
      //           'tid': samples.samples![0].tid,
      //           'ts': samples.samples![0].timestamp,
      //           'cat': 'Dart',
      //           'sf': '$isolateId-4',
      //           'args': {'userTag': '__userTag', 'vmTag': '__vmTag'},
      //         },
      //       ],
      //     };

      //     final cpuProfileData = await CpuProfileData.generateFromCpuSamples(
      //       isolateId,
      //       origin,
      //       extent,
      //     );

      //     expect(
      //       cpuProfileData.toJson,
      //       equals(expectedCpuProfileTimeline),
      //     );
      //   });
    });

    test('subProfile', () {
      final subProfile = CpuProfileData.subProfile(
        cpuProfileData,
        TimeRange()
          ..start = const Duration(microseconds: 47377796685)
          ..end = const Duration(microseconds: 47377799063),
      );

      expect(
        subProfile.stackFramesJson,
        equals(subProfileStackFrames),
      );
      expect(
        subProfile.cpuSamples.map((sample) => sample.json),
        equals(subProfileTraceEvents),
      );
      expect(subProfile.profileMetaData.sampleCount, equals(3));
      expect(
        subProfile.profileMetaData.samplePeriod,
        equals(cpuProfileData.profileMetaData.samplePeriod),
      );
    });

    test('filterFrom', () {
      final filteredProfile = CpuProfileData.filterFrom(
        cpuProfileData,
        (stackFrame) => !stackFrame.processedUrl.startsWith('dart:'),
      );
      expect(
        filteredProfile.stackFramesJson,
        equals(filteredStackFrames),
      );
      expect(
        filteredProfile.cpuSamples.map((sample) => sample.toJson),
        equals(filteredCpuSampleTraceEvents),
      );
      expect(filteredProfile.profileMetaData.sampleCount, equals(8));
      expect(
        filteredProfile.profileMetaData.samplePeriod,
        equals(cpuProfileData.profileMetaData.samplePeriod),
      );
    });

    test('samples to json', () {
      expect(cpuSamples.toJson(), equals(CpuSamples.parse(goldenSamplesJson)));
    });

    test('converts golden samples to golden cpu profile data', () async {
      final cpuProfileData = await CpuProfileData.generateFromCpuSamples(
        goldenSamplesIsolate,
        CpuSamples.parse(goldenSamplesJson)!,
      );
      expect(cpuProfileData.toJson, equals(goldenCpuProfileDataJson));
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
    test('isNative', () {
      expect(stackFrameA.isNative, isTrue);
      expect(stackFrameB.isNative, isFalse);
      expect(stackFrameC.isNative, isFalse);
      expect(flutterEngineStackFrame.isNative, isFalse);
      expect(
        CpuStackFrame(
          id: CpuProfileData.rootId,
          name: CpuProfileData.rootName,
          verboseName: 'all',
          category: 'Dart',
          rawUrl: '',
          sourceLine: null,
          parentId: '',
          profileMetaData: profileMetaData,
        ).isNative,
        isFalse,
      );
    });

    test('isDartCore', () {
      expect(stackFrameA.isDartCore, isFalse);
      expect(stackFrameB.isDartCore, isTrue);
      expect(stackFrameC.isDartCore, isFalse);
    });

    test('isFlutterCore', () {
      expect(stackFrameA.isFlutterCore, isFalse);
      expect(stackFrameB.isFlutterCore, isFalse);
      expect(stackFrameC.isFlutterCore, isTrue);
      expect(flutterEngineStackFrame.isFlutterCore, isTrue);
    });

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
      CpuStackFrame copy =
          stackFrameD.shallowCopy(resetInclusiveSampleCount: false);
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
      copy = stackFrameD.shallowCopy();
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
      testStackFrame.expand();
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

    test('handles zero values', () {
      expect(zeroStackFrame.totalTime, const Duration());
      expect(zeroStackFrame.totalTimeRatio, 0.0);
      expect(zeroStackFrame.selfTime, const Duration());
      expect(zeroStackFrame.selfTimeRatio, 0.0);
    });
  });

  test('matches', () {
    expect(stackFrameC.matches(stackFrameC2), isTrue);
    expect(stackFrameC.matches(stackFrameG), isFalse);
    expect(stackFrameC.matches(stackFrameC4), isFalse);
  });
}
