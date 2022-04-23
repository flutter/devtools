// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profile_controller.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profile_model.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import 'test_data/cpu_profile_test_data.dart';

void main() {
  final ServiceConnectionManager fakeServiceManager = FakeServiceManager(
    service: FakeServiceManager.createFakeService(
      cpuSamples: CpuSamples.parse(goldenCpuSamplesJson),
      resolvedUriMap: goldenResolvedUriMap,
    ),
  );
  final app = fakeServiceManager.connectedApp!;
  when(app.isFlutterAppNow).thenReturn(true);

  group('CpuProfileController', () {
    late CpuProfilerController controller;

    setUp(() {
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(OfflineModeController, OfflineModeController());
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
      expect(controller.processingNotifier.value, false);

      // [startMicros] and [extentMicros] are arbitrary for testing.
      await controller.pullAndProcessProfile(
        startMicros: 0,
        extentMicros: 100,
        processId: 'test',
      );
      expect(
        controller.dataNotifier.value,
        isNot(equals(CpuProfilerController.baseStateCpuProfileData)),
      );
      expect(controller.processingNotifier.value, false);

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
      final filteredData = controller.dataNotifier.value!;
      expect(originalData.stackFrames.values.length, equals(17));
      expect(filteredData.stackFrames.values.length, equals(12));

      // The native frame filter is applied by default.
      final originalNativeFrames =
          originalData.stackFrames.values.where((sf) => sf.isNative).toList();
      final filteredNativeFrames =
          filteredData.stackFrames.values.where((sf) => sf.isNative).toList();
      expect(originalNativeFrames.length, equals(5));
      expect(filteredNativeFrames, isEmpty);
    });

    test('generateToggleFilterSuffix', () {
      for (final toggleFilter in controller.toggleFilters) {
        toggleFilter.enabled.value = false;
      }
      expect(controller.generateToggleFilterSuffix(), equals(''));

      controller.toggleFilters[0].enabled.value = true;
      expect(
        controller.generateToggleFilterSuffix(),
        equals('Hide Native code'),
      );

      controller.toggleFilters[1].enabled.value = true;
      expect(
        controller.generateToggleFilterSuffix(),
        equals('Hide Native code,Hide core Dart libraries'),
      );

      controller.toggleFilters[2].enabled.value = true;
      expect(
        controller.generateToggleFilterSuffix(),
        equals(
          'Hide Native code,Hide core Dart libraries,Hide core Flutter libraries',
        ),
      );

      controller.toggleFilters[1].enabled.value = false;
      expect(
        controller.generateToggleFilterSuffix(),
        equals('Hide Native code,Hide core Flutter libraries'),
      );
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
      // Disable all filtering by default for this sake of this test.
      for (final filter in controller.toggleFilters) {
        filter.enabled.value = false;
      }

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
        controller.matchesForSearch('rendering/.*\.dart').length,
        equals(7),
      );
      expect(controller.matchesForSearch('RENDER.*\.paint').length, equals(6));
    });

    test('matchesForSearch sets isSearchMatch property', () async {
      // Disable all filtering by default for this sake of this test.
      for (final filter in controller.toggleFilters) {
        filter.enabled.value = false;
      }

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
      // Disable toggle filters for the purpose of this test.
      for (final toggleFilter in controller.toggleFilters) {
        toggleFilter.enabled.value = false;
      }

      final cpuProfileDataWithTags =
          CpuProfileData.parse(cpuProfileDataWithUserTagsJson);
      await controller.transformer.processData(
        cpuProfileDataWithTags,
        processId: 'test',
      );
      controller.loadProcessedData(
        cpuProfileDataWithTags,
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
    });

    test('processDataForTag applies toggle filters by default', () async {
      expect(controller.toggleFilters[0].enabled.value, isTrue);
      final cpuProfileDataWithTags =
          CpuProfileData.parse(cpuProfileDataWithUserTagsJson);
      await controller.transformer.processData(
        cpuProfileDataWithTags,
        processId: 'test',
      );
      controller.loadProcessedData(
        cpuProfileDataWithTags,
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
    });

    test('reset', () async {
      await pullProfileAndSelectFrame();
      controller.reset();
      expect(
        controller.dataNotifier.value,
        equals(CpuProfilerController.baseStateCpuProfileData),
      );
      expect(controller.selectedCpuStackFrameNotifier.value, isNull);
      expect(controller.processingNotifier.value, isFalse);
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
          controller.processingNotifier.addListener(() {});
        },
        throwsA(anything),
      );
    });
  });
}
