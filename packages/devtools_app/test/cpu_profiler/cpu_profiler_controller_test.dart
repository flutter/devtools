// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profiler_controller.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_test_utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../test_infra/test_data/cpu_profiler/cpu_profile.dart';

void main() {
  late ServiceConnectionManager fakeServiceManager;

  setUp(() {
    fakeServiceManager = FakeServiceConnectionManager(
      service: FakeServiceManager.createFakeService(
        cpuSamples: CpuSamples.parse(goldenCpuSamplesJson),
        resolvedUriMap: goldenResolvedUriMap,
      ),
    );
    final app = fakeServiceManager.serviceManager.connectedApp!;
    when(app.isFlutterAppNow).thenReturn(true);
  });

  group('CpuProfileController', () {
    late CpuProfilerController controller;

    Future<void> disableAllFiltering() async {
      for (final filter in controller.activeFilter.value.toggleFilters) {
        filter.enabled.value = false;
      }
      controller.setActiveFilter();
      // [CpuProfilerController.filterData], which is triggered by the call to
      // [setActiveFilter] via a listener callback, calls an unawaited future.
      // We await a short delay here to ensure that that future completes.
      await shortDelay();
    }

    setUp(() {
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(OfflineModeController, OfflineModeController());
      setGlobal(PreferencesController, PreferencesController());
      controller = CpuProfilerController();
    });

    Future<void> pullProfileAndSelectFrame() async {
      await controller.pullAndProcessProfile(
        startMicros: 0,
        extentMicros: 100,
        processId: 'test',
      );
      controller.selectCpuStackFrame(testStackFrame);
      expect(
        controller.dataNotifier.value,
        isNot(equals(CpuProfilerController.baseStateCpuProfileData)),
      );
      expect(
        controller.selectedCpuStackFrameNotifier.value,
        equals(testStackFrame),
      );
    }

    test('pullAndProcessProfile', () async {
      expect(
        controller.dataNotifier.value,
        equals(CpuProfilerController.baseStateCpuProfileData),
      );
      expect(controller.profilerBusyStatus.value, CpuProfilerBusyStatus.none);

      // [startMicros] and [extentMicros] are arbitrary for testing.
      await controller.pullAndProcessProfile(
        startMicros: 0,
        extentMicros: 100,
        processId: 'test',
      );
      expect(
        controller.dataNotifier.value !=
            CpuProfilerController.baseStateCpuProfileData,
        isTrue,
      );
      expect(controller.profilerBusyStatus.value, CpuProfilerBusyStatus.none);

      await controller.clear();
      expect(
        controller.dataNotifier.value,
        equals(CpuProfilerController.baseStateCpuProfileData),
      );
    });

    test('loads filtered data by default', () async {
      // [startMicros] and [extentMicros] are arbitrary for testing.
      await controller.pullAndProcessProfile(
        startMicros: 0,
        extentMicros: 100,
        processId: 'test',
      );
      final originalData = controller.cpuProfileStore.lookupProfile(
        label: CpuProfilerController.userTagNone,
      )!;
      expect(
        originalData.functionProfile.stackFrames.values.length,
        equals(17),
      );

      final filteredData = controller.dataNotifier.value!;
      expect(filteredData.stackFrames.values.length, equals(12));

      // The native frame filter is applied by default.
      final originalNativeFrames = originalData
          .functionProfile.stackFrames.values
          .where((sf) => sf.isNative)
          .toList();
      final filteredNativeFrames =
          filteredData.stackFrames.values.where((sf) => sf.isNative).toList();
      expect(originalNativeFrames.length, equals(5));
      expect(filteredNativeFrames, isEmpty);
    });

    test('filters data by query filter', () async {
      // [startMicros] and [extentMicros] are arbitrary for testing.
      await controller.pullAndProcessProfile(
        startMicros: 0,
        extentMicros: 100,
        processId: 'test',
      );
      final originalData = controller.cpuProfileStore.lookupProfile(
        label: CpuProfilerController.userTagNone,
      )!;
      expect(
        originalData.functionProfile.stackFrames.values.length,
        equals(17),
      );

      // At this point, data is filtered by the default toggle filter values.
      var filteredData = controller.dataNotifier.value!;
      expect(filteredData.stackFrames.values.length, equals(12));

      // [CpuProfilerController.filterData], which is triggered by the call to
      // [setActiveFilter] via a listener callback, calls an unawaited future.
      // We await a short delay here and below to ensure that that future
      // completes.
      controller.setActiveFilter(query: 'uri:dart:vm');
      await shortDelay();
      filteredData = controller.dataNotifier.value!;
      expect(filteredData.stackFrames.values.length, equals(3));

      controller.setActiveFilter(query: 'render uri:dart:vm');
      await shortDelay();
      filteredData = controller.dataNotifier.value!;
      expect(filteredData.stackFrames.values.length, equals(2));

      controller.setActiveFilter(query: 'abcdefg some bogus value');
      await shortDelay();
      filteredData = controller.dataNotifier.value!;
      expect(filteredData.stackFrames.values.length, equals(0));

      // 'thread' events are excluded because Native frames are hidden by
      // default.
      controller.setActiveFilter(query: 'paint thread');
      await shortDelay();
      filteredData = controller.dataNotifier.value!;
      expect(filteredData.stackFrames.values.length, equals(7));

      for (final filter in controller.activeFilter.value.toggleFilters) {
        filter.enabled.value = false;
      }
      controller.setActiveFilter(query: 'paint thread');
      await shortDelay();
      filteredData = controller.dataNotifier.value!;
      expect(filteredData.stackFrames.values.length, equals(9));
    });

    test('selectCpuStackFrame', () async {
      final dataNotifierValue = controller.dataNotifier.value!;

      expect(
        dataNotifierValue.selectedStackFrame,
        isNull,
      );
      expect(controller.selectedCpuStackFrameNotifier.value, isNull);
      controller.selectCpuStackFrame(testStackFrame);
      expect(
        dataNotifierValue.selectedStackFrame,
        equals(testStackFrame),
      );
      expect(
        controller.selectedCpuStackFrameNotifier.value,
        equals(testStackFrame),
      );

      await controller.clear();
      expect(controller.selectedCpuStackFrameNotifier.value, isNull);
    });

    test('matchesForSearch', () async {
      await disableAllFiltering();

      // [startMicros] and [extentMicros] are arbitrary for testing.
      await controller.pullAndProcessProfile(
        startMicros: 0,
        extentMicros: 100,
        processId: 'test',
      );
      expect(
        controller.dataNotifier.value!.stackFrames.values.length,
        equals(17),
      );

      // Match on name.
      expect(controller.matchesForSearch('').length, equals(0));
      expect(controller.matchesForSearch('render').length, equals(9));
      expect(controller.matchesForSearch('RenderObject').length, equals(3));
      expect(controller.matchesForSearch('THREAD').length, equals(2));
      expect(controller.matchesForSearch('paint').length, equals(7));

      // Match on url.
      expect(controller.matchesForSearch('rendering/').length, equals(7));
      expect(controller.matchesForSearch('proxy_box.dart').length, equals(1));
      expect(controller.matchesForSearch('dart:').length, equals(3));

      // Match with RegExp.
      expect(
        controller.matchesForSearch('rendering/.*.dart').length,
        equals(7),
      );
      expect(controller.matchesForSearch('RENDER.*.paint').length, equals(6));
    });

    test('matchesForSearch sets isSearchMatch property', () async {
      await disableAllFiltering();

      // [startMicros] and [extentMicros] are arbitrary for testing.
      await controller.pullAndProcessProfile(
        startMicros: 0,
        extentMicros: 100,
        processId: 'test',
      );

      final dataNotifierValue = controller.dataNotifier.value!;

      expect(dataNotifierValue.stackFrames.values.length, equals(17));

      controller.search = 'render';
      var matches = controller.searchMatches.value;
      verifyIsSearchMatchForTreeData(
        dataNotifierValue.stackFrames.values.toList(),
        matches,
      );

      controller.search = 'THREAD';
      matches = controller.searchMatches.value;
      verifyIsSearchMatchForTreeData(
        dataNotifierValue.stackFrames.values.toList(),
        matches,
      );
    });

    test('processDataForTag', () async {
      await disableAllFiltering();

      final cpuProfileDataWithTags =
          CpuProfileData.parse(cpuProfileDataWithUserTagsJson);
      await controller.transformer.processData(
        cpuProfileDataWithTags,
        processId: 'test',
      );
      controller.loadProcessedData(
        CpuProfilePair(
          functionProfile: cpuProfileDataWithTags,
          codeProfile: null,
        ),
        storeAsUserTagNone: true,
      );

      final dataNotifierValue = controller.dataNotifier.value!;

      expect(
        dataNotifierValue
            .cpuProfileRoot.profileMetaData.time!.duration.inMicroseconds,
        equals(250),
      );
      expect(
        dataNotifierValue.cpuProfileRoot.profileAsString(),
        equals(
          '''
  all - children: 1 - excl: 0 - incl: 5
    Frame1 - children: 2 - excl: 0 - incl: 5
      Frame2 - children: 2 - excl: 0 - incl: 2
        Frame3 - children: 0 - excl: 1 - incl: 1
        Frame4 - children: 0 - excl: 1 - incl: 1
      Frame5 - children: 1 - excl: 2 - incl: 3
        Frame6 - children: 0 - excl: 1 - incl: 1
''',
        ),
      );

      await controller.loadDataWithTag('userTagA');
      expect(
        controller.dataNotifier.value!.cpuProfileRoot.profileAsString(),
        equals(
          '''
  all - children: 1 - excl: 0 - incl: 2
    Frame1 - children: 2 - excl: 0 - incl: 2
      Frame2 - children: 1 - excl: 0 - incl: 1
        Frame3 - children: 0 - excl: 1 - incl: 1
      Frame5 - children: 0 - excl: 1 - incl: 1
''',
        ),
      );

      await controller.loadDataWithTag('userTagB');
      expect(
        controller.dataNotifier.value!.cpuProfileRoot.profileAsString(),
        equals(
          '''
  all - children: 1 - excl: 0 - incl: 1
    Frame1 - children: 1 - excl: 0 - incl: 1
      Frame2 - children: 1 - excl: 0 - incl: 1
        Frame4 - children: 0 - excl: 1 - incl: 1
''',
        ),
      );

      await controller.loadDataWithTag('userTagC');
      expect(
        controller.dataNotifier.value!.cpuProfileRoot.profileAsString(),
        equals(
          '''
  all - children: 1 - excl: 0 - incl: 2
    Frame1 - children: 1 - excl: 0 - incl: 2
      Frame5 - children: 1 - excl: 1 - incl: 2
        Frame6 - children: 0 - excl: 1 - incl: 1
''',
        ),
      );

      await controller.loadDataWithTag(CpuProfilerController.groupByUserTag);
      expect(
        controller.dataNotifier.value!.cpuProfileRoot.profileAsString(),
        profileGroupedByUserTagsGolden,
      );

      await controller.loadDataWithTag(CpuProfilerController.groupByVmTag);
      expect(
        controller.dataNotifier.value!.cpuProfileRoot.profileAsString(),
        profileGroupedByVmTagsGolden,
      );
    });

    test('processDataForTag applies toggle filters by default', () async {
      expect(
        controller.activeFilter.value.toggleFilters[0].enabled.value,
        isTrue,
      );
      final cpuProfileDataWithTags =
          CpuProfileData.parse(cpuProfileDataWithUserTagsJson);
      await controller.transformer.processData(
        cpuProfileDataWithTags,
        processId: 'test',
      );
      controller.loadProcessedData(
        CpuProfilePair(
          functionProfile: cpuProfileDataWithTags,
          codeProfile: null,
        ),
        storeAsUserTagNone: true,
      );

      final cpuProfileRoot = controller.dataNotifier.value!.cpuProfileRoot;
      expect(
        cpuProfileRoot.profileMetaData.time!.duration.inMicroseconds,
        equals(250),
      );
      expect(
        cpuProfileRoot.profileAsString(),
        equals(
          '''
  all - children: 1 - excl: 0 - incl: 5
    Frame1 - children: 2 - excl: 0 - incl: 5
      Frame2 - children: 2 - excl: 0 - incl: 2
        Frame3 - children: 0 - excl: 1 - incl: 1
        Frame4 - children: 0 - excl: 1 - incl: 1
      Frame5 - children: 1 - excl: 2 - incl: 3
        Frame6 - children: 0 - excl: 1 - incl: 1
''',
        ),
      );

      await controller.loadDataWithTag('userTagA');
      expect(
        controller.dataNotifier.value!.cpuProfileRoot.profileAsString(),
        equals(
          '''
  all - children: 2 - excl: 0 - incl: 2
    Frame2 - children: 0 - excl: 1 - incl: 1
    Frame5 - children: 0 - excl: 1 - incl: 1
''',
        ),
      );

      await controller.loadDataWithTag('userTagB');
      expect(
        controller.dataNotifier.value!.cpuProfileRoot.profileAsString(),
        equals(
          '''
  all - children: 1 - excl: 0 - incl: 1
    Frame2 - children: 0 - excl: 1 - incl: 1
''',
        ),
      );

      await controller.loadDataWithTag('userTagC');
      expect(
        controller.dataNotifier.value!.cpuProfileRoot.profileAsString(),
        equals(
          '''
  all - children: 1 - excl: 0 - incl: 2
    Frame5 - children: 1 - excl: 1 - incl: 2
      Frame6 - children: 0 - excl: 1 - incl: 1
''',
        ),
      );

      await controller.loadDataWithTag(CpuProfilerController.groupByUserTag);
      expect(
        controller.dataNotifier.value!.cpuProfileRoot.profileAsString(),
        equals(
          '''
  all - children: 3 - excl: 0 - incl: 5
    userTagA - children: 2 - excl: 0 - incl: 2
      Frame2 - children: 0 - excl: 1 - incl: 1
      Frame5 - children: 0 - excl: 1 - incl: 1
    userTagB - children: 1 - excl: 0 - incl: 1
      Frame2 - children: 0 - excl: 1 - incl: 1
    userTagC - children: 1 - excl: 0 - incl: 2
      Frame5 - children: 1 - excl: 1 - incl: 2
        Frame6 - children: 0 - excl: 1 - incl: 1
''',
        ),
      );

      await controller.loadDataWithTag(CpuProfilerController.groupByVmTag);
      expect(
        controller.dataNotifier.value!.cpuProfileRoot.profileAsString(),
        equals(
          '''
  all - children: 3 - excl: 0 - incl: 5
    vmTagA - children: 2 - excl: 0 - incl: 2
      Frame2 - children: 0 - excl: 1 - incl: 1
      Frame5 - children: 0 - excl: 1 - incl: 1
    vmTagB - children: 1 - excl: 0 - incl: 1
      Frame2 - children: 0 - excl: 1 - incl: 1
    vmTagC - children: 1 - excl: 0 - incl: 2
      Frame5 - children: 1 - excl: 1 - incl: 2
        Frame6 - children: 0 - excl: 1 - incl: 1
''',
        ),
      );
    });

    test('reset', () async {
      await pullProfileAndSelectFrame();
      controller.reset();
      expect(
        controller.dataNotifier.value,
        equals(CpuProfilerController.baseStateCpuProfileData),
      );
      expect(controller.selectedCpuStackFrameNotifier.value, isNull);
      expect(controller.profilerBusyStatus.value, CpuProfilerBusyStatus.none);
    });

    test('disposes', () {
      controller.dispose();
      expect(
        () {
          controller.dataNotifier.addListener(() {});
        },
        throwsA(anything),
      );
      expect(
        () {
          controller.selectedCpuStackFrameNotifier.addListener(() {});
        },
        throwsA(anything),
      );
      expect(
        () {
          controller.profilerBusyStatus.addListener(() {});
        },
        throwsA(anything),
      );
    });
  });
}
