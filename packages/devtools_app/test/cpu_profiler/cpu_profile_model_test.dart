// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/profiler/cpu_profile_model.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/primitives/utils.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import '../test_infra/test_data/cpu_profiler/cpu_profile.dart';

void main() {
  group('CpuProfileData', () {
    final cpuProfileData = CpuProfileData.parse(cpuProfileResponseJson);
    final cpuSamples = CpuSamples.parse(goldenCpuSamplesJson)!;

    setUp(() {
      setGlobal(
        ServiceConnectionManager,
        FakeServiceConnectionManager(
          service: FakeServiceManager.createFakeService(
            resolvedUriMap: goldenResolvedUriMap,
          ),
        ),
      );
    });

    test(
      'empty frame regression test',
      () {
        final cpuProfileEmptyData =
            CpuProfileData.parse(cpuProfileResponseEmptyJson);
        expect(
          cpuProfileEmptyData.profileMetaData.time!.end!.inMilliseconds,
          47377796,
        );
        final filtered =
            CpuProfileData.filterFrom(cpuProfileEmptyData, (_) => true);
        expect(filtered.profileMetaData.time!.end!.inMilliseconds, 0);
      },
    );

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

    test(
      'converts golden samples to golden cpu profile data',
      () async {
        final generatedCpuProfileData =
            await CpuProfileData.generateFromCpuSamples(
          isolateId: goldenSamplesIsolate,
          cpuSamples: CpuSamples.parse(goldenCpuSamplesJson)!,
        );

        expect(
          generatedCpuProfileData.toJson,
          equals(goldenCpuProfileDataJson),
        );
      },
    );

    test(
      'to json defaults packageUri to resolvedUrl',
      () {
        const id = '140357727781376-12';

        final profileData = Map.of(goldenCpuProfileDataJson);
        final stackFrame = goldenCpuProfileStackFrames[id] as Map;
        final stackFrameData = {id: stackFrame};
        profileData['stackFrames'] = stackFrameData;
        stackFrameData[id]!.remove(CpuProfileData.resolvedPackageUriKey);

        final parsedProfileData = CpuProfileData.parse(profileData);

        final jsonPackageUri = parsedProfileData.stackFrames[id]!.packageUri;
        expect(jsonPackageUri, stackFrame['resolvedUrl']);
      },
    );

    test('generateFromCpuSamples handles duplicate resolvedUrls', () async {
      const resolvedUrl = 'the/resolved/Url';
      const packageUri = 'the/package/Uri';
      setGlobal(
        ServiceConnectionManager,
        FakeServiceConnectionManager(
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
          isTag: false,
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

    test('isTag', () {
      expect(stackFrameA.isTag, isFalse);
      expect(stackFrameB.isTag, isFalse);
      expect(stackFrameC.isTag, isFalse);
      expect(flutterEngineStackFrame.isTag, isFalse);
      expect(
        CpuStackFrame(
          id: CpuProfileData.rootId,
          name: 'MyTag',
          verboseName: 'MyTag',
          category: 'Dart',
          rawUrl: '',
          packageUri: '',
          sourceLine: null,
          parentId: '',
          profileMetaData: profileMetaData,
          isTag: true,
        ).isTag,
        isTrue,
      );
    });

    test('sampleCount', () {
      expect(testStackFrame.inclusiveSampleCount, equals(10));
    });

    test('totalTime and selfTime', () {
      expect(testStackFrame.totalTimeRatio, equals(1.0));
      expect(testStackFrame.totalTime.inMicroseconds, equals(10000));
      expect(testStackFrame.selfTimeRatio, equals(0.0));
      expect(testStackFrame.selfTime.inMicroseconds, equals(0));

      expect(stackFrameC.totalTimeRatio, equals(0.2));
      expect(stackFrameC.totalTime.inMicroseconds, equals(2000));
      expect(stackFrameC.selfTimeRatio, equals(0.2));
      expect(stackFrameC.selfTime.inMicroseconds, equals(2000));

      expect(stackFrameD.totalTimeRatio, equals(0.8));
      expect(stackFrameD.totalTime.inMicroseconds, equals(8000));
      expect(stackFrameD.selfTimeRatio, equals(0.2));
      expect(stackFrameD.selfTime.inMicroseconds, equals(2000));

      expect(stackFrameF.totalTimeRatio, equals(0.1));
      expect(stackFrameF.totalTime.inMicroseconds, equals(1000));
      expect(stackFrameF.selfTimeRatio, equals(0.0));
      expect(stackFrameF.selfTime.inMicroseconds, equals(0));
    });

    test('ancestorIds', () {
      expect(testStackFrame.ancestorIds.toList(), ['cpuProfileRoot']);
      expect(stackFrameA.ancestorIds.toList(), ['cpuProfileRoot']);
      expect(stackFrameB.ancestorIds.toList(), ['id_0', 'cpuProfileRoot']);
      expect(
        stackFrameC.ancestorIds.toList(),
        ['id_1', 'id_0', 'cpuProfileRoot'],
      );
      expect(
        stackFrameD.ancestorIds.toList(),
        ['id_1', 'id_0', 'cpuProfileRoot'],
      );
      expect(
        stackFrameE.ancestorIds.toList(),
        ['id_3', 'id_1', 'id_0', 'cpuProfileRoot'],
      );
      expect(
        stackFrameF.ancestorIds.toList(),
        ['id_4', 'id_3', 'id_1', 'id_0', 'cpuProfileRoot'],
      );
      expect(
        stackFrameF2.ancestorIds.toList(),
        ['id_3', 'id_1', 'id_0', 'cpuProfileRoot'],
      );
      expect(
        stackFrameC2.ancestorIds.toList(),
        ['id_5', 'id_4', 'id_3', 'id_1', 'id_0', 'cpuProfileRoot'],
      );
      expect(
        stackFrameC3.ancestorIds.toList(),
        ['id_6', 'id_3', 'id_1', 'id_0', 'cpuProfileRoot'],
      );
    });

    test('shallowCopy', () {
      expect(stackFrameD.children.length, 2);
      expect(stackFrameD.parent, stackFrameB);
      CpuStackFrame copy = stackFrameD.shallowCopy();
      expect(copy.children, isEmpty);
      expect(copy.parent, isNull);
      expect(copy.exclusiveSampleCount, stackFrameD.exclusiveSampleCount);
      expect(copy.inclusiveSampleCount, stackFrameD.inclusiveSampleCount);
      expect(copy.sourceLine, stackFrameD.sourceLine);

      expect(stackFrameD.children.length, 2);
      expect(stackFrameD.parent, stackFrameB);
      copy = stackFrameD.shallowCopy(copySampleCounts: false);
      expect(copy.children, isEmpty);
      expect(copy.parent, isNull);
      expect(copy.exclusiveSampleCount, 0);
      expect(copy.inclusiveSampleCount, 0);
      expect(copy.sourceLine, stackFrameD.sourceLine);
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
        testTagRootedStackFrame.tooltip,
        equals('[Tag] TagA - 10.0 ms'),
      );
      expect(
        stackFrameA.tooltip,
        equals('[Native] A - 10.0 ms'),
      );
      expect(
        stackFrameB.tooltip,
        equals('[Dart] B - 10.0 ms - dart:async/zone.dart:2222'),
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
