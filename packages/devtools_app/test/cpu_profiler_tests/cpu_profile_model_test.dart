// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/primitives/utils.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profile_model.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import '../test_data/cpu_profile.dart';

void main() {
  group('CpuProfileData', () {
    final cpuProfileData = CpuProfileData.parse(cpuProfileResponseJson);
    final cpuSamples = CpuSamples.parse(goldenCpuSamplesJson)!;

    setUp(() {
      setGlobal(
        ServiceConnectionManager,
        FakeServiceManager(
          service: FakeServiceManager.createFakeService(
            resolvedUriMap: goldenResolvedUriMap,
          ),
        ),
      );
    });
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
        (stackFrame) => !stackFrame.packageUri.startsWith('dart:'),
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
      expect(cpuSamples.toJson(), equals(goldenCpuSamplesJson));
    });

    test('profileData to json', () {
      expect(cpuProfileData.toJson, equals(goldenCpuProfileDataJson));
    });

    test('converts golden samples to golden cpu profile data', () async {
      final generatedCpuProfileData =
          await CpuProfileData.generateFromCpuSamples(
        isolateId: goldenSamplesIsolate,
        cpuSamples: CpuSamples.parse(goldenCpuSamplesJson)!,
      );

      expect(generatedCpuProfileData.toJson, equals(goldenCpuProfileDataJson));
    });

    test('to json defaults packageUri to resolvedUrl', () {
      const id = '140357727781376-12';
      final profileData = Map<String, dynamic>.from(goldenCpuProfileDataJson);
      profileData['stackFrames'] = Map<String, Map<String, String?>>.from(
        {id: goldenCpuProfileStackFrames[id]},
      );
      profileData['stackFrames'][id]
          .remove(CpuProfileData.resolvedPackageUriKey);

      final parsedProfileData = CpuProfileData.parse(profileData);

      final jsonPackageUri = parsedProfileData.stackFrames[id]!.packageUri;
      expect(jsonPackageUri, goldenCpuProfileStackFrames[id]!['resolvedUrl']);
    });

    test('generateFromCpuSamples handles duplicate resolvedUrls', () async {
      const resolvedUrl = 'the/resolved/Url';
      const packageUri = 'the/package/Uri';
      setGlobal(
        ServiceConnectionManager,
        FakeServiceManager(
          service: FakeServiceManager.createFakeService(
            resolvedUriMap: {resolvedUrl: packageUri},
          ),
        ),
      );
      final cpuSamples = CpuSamples.parse(goldenCpuSamplesJson);
      cpuSamples!.functions = cpuSamples.functions!.sublist(0, 3);
      cpuSamples.samples = cpuSamples.samples!.sublist(0, 2);
      cpuSamples.samples![0].stack = [0];
      cpuSamples.samples![1].stack = [1];
      cpuSamples.functions![0].resolvedUrl = resolvedUrl;
      cpuSamples.functions![1].resolvedUrl = resolvedUrl;
      cpuSamples.sampleCount = 2;

      final cpuProfileData = await CpuProfileData.generateFromCpuSamples(
        isolateId: goldenSamplesIsolate,
        cpuSamples: cpuSamples,
      );

      expect(cpuProfileData.stackFrames.length, equals(2));
      expect(
        cpuProfileData.stackFrames.values.toList()[0].packageUri,
        equals(packageUri),
      );
      expect(
        cpuProfileData.stackFrames.values.toList()[1].packageUri,
        equals(packageUri),
      );
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
          packageUri: '',
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
      expect(copy.sourceLine, equals(stackFrameD.sourceLine));
    });

    test('shallowCopy overrides', () {
      final overrides = {
        'id': 'overriddenId',
        'name': 'overriddenName',
        'verboseName': 'overriddenVerboseName',
        'category': 'overriddenCategory',
        'url': 'overriddenUrl',
        'packageUri': 'overriddenPackageUri',
        'parentId': 'overriddenParentId',
      };
      const overriddenSourceLine = 98329;

      final copy = stackFrameC.shallowCopy(
        id: overrides['id']!,
        name: overrides['name']!,
        verboseName: overrides['verboseName']!,
        category: overrides['category']!,
        url: overrides['url']!,
        packageUri: overrides['packageUri']!,
        parentId: overrides['parentId']!,
        sourceLine: overriddenSourceLine,
        profileMetaData: stackFrameD.profileMetaData,
      );

      expect(copy.id, equals(overrides['id']));
      expect(copy.name, equals(overrides['name']));
      expect(copy.verboseName, equals(overrides['verboseName']));
      expect(copy.category, equals(overrides['category']));
      expect(copy.rawUrl, equals(overrides['url']));
      expect(copy.packageUri, equals(overrides['packageUri']));
      expect(copy.parentId, equals(overrides['parentId']));
      expect(copy.sourceLine, equals(overriddenSourceLine));
      expect(copy.profileMetaData, stackFrameD.profileMetaData);
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

    test('tooltip', () {
      expect(
        stackFrameA.tooltip,
        equals('[Native] A - 0.1 ms'),
      );
      expect(
        stackFrameB.tooltip,
        equals('[Dart] B - 0.1 ms - dart:async/zone.dart:2222'),
      );
    });

    group('packageUriWithSourceLine', () {
      test('with a sourceLine', () {
        const sourceLine = 38239;
        final copy = stackFrameD.shallowCopy(sourceLine: sourceLine);
        expect(
          copy.packageUriWithSourceLine,
          equals('processedflutter::AnimatorBeginFrame:$sourceLine'),
        );
      });

      test('without sourceLine', () {
        expect(
          stackFrameD.packageUriWithSourceLine,
          equals('processedflutter::AnimatorBeginFrame'),
        );
      });
    });
  });

  test('matches', () {
    expect(stackFrameC.matches(stackFrameC2), isTrue);
    expect(stackFrameC.matches(stackFrameG), isFalse);
    expect(stackFrameC.matches(stackFrameC4), isFalse);
  });
}
