// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/profiler/cpu_profile_controller.dart';
import 'package:devtools_app/src/profiler/cpu_profile_model.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/cpu_profile_test_data.dart';
import 'support/mocks.dart';
import 'support/utils.dart';

void main() {
  group('CpuProfileController', () {
    CpuProfilerController controller;
    FakeServiceManager fakeServiceManager;

    setUp(() {
      fakeServiceManager = FakeServiceManager();
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      controller = CpuProfilerController();
    });

    Future<void> pullProfileAndSelectFrame() async {
      await controller.pullAndProcessProfile(startMicros: 0, extentMicros: 100);
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
      await controller.pullAndProcessProfile(startMicros: 0, extentMicros: 100);
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

    test('selectCpuStackFrame', () async {
      expect(
        controller.dataNotifier.value.selectedStackFrame,
        isNull,
      );
      expect(controller.selectedCpuStackFrameNotifier.value, isNull);
      controller.selectCpuStackFrame(testStackFrame);
      expect(
        controller.dataNotifier.value.selectedStackFrame,
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
      // [startMicros] and [extentMicros] are arbitrary for testing.
      await controller.pullAndProcessProfile(startMicros: 0, extentMicros: 100);
      expect(
          controller.dataNotifier.value.stackFrames.values.length, equals(17));

      // Match on name.
      expect(controller.matchesForSearch(null).length, equals(0));
      expect(controller.matchesForSearch('').length, equals(0));
      expect(controller.matchesForSearch('render').length, equals(9));
      expect(controller.matchesForSearch('RenderObject').length, equals(3));
      expect(controller.matchesForSearch('THREAD').length, equals(2));
      expect(controller.matchesForSearch('paint').length, equals(7));

      // Match on url.
      expect(controller.matchesForSearch('rendering/').length, equals(9));
      expect(controller.matchesForSearch('proxy_box.dart').length, equals(2));
      expect(controller.matchesForSearch('dartlang-sdk').length, equals(1));

      // Match with RegExp.
      expect(
          controller.matchesForSearch('rendering/.*\.dart').length, equals(9));
      expect(controller.matchesForSearch('RENDER.*\.paint').length, equals(6));
    });

    test('matchesForSearch sets isSearchMatch property', () async {
      // [startMicros] and [extentMicros] are arbitrary for testing.
      await controller.pullAndProcessProfile(startMicros: 0, extentMicros: 100);
      expect(
          controller.dataNotifier.value.stackFrames.values.length, equals(17));

      var matches = controller.matchesForSearch('render');
      verifyIsSearchMatch(
        controller.dataNotifier.value.stackFrames.values.toList(),
        matches,
      );

      matches = controller.matchesForSearch('THREAD');
      verifyIsSearchMatch(
        controller.dataNotifier.value.stackFrames.values.toList(),
        matches,
      );
    });

    test('processDataForTag', () async {
      final cpuProfileDataWithTags =
          CpuProfileData.parse(cpuProfileDataWithUserTagsJson);
      await controller.transformer.processData(cpuProfileDataWithTags);
      controller.loadProcessedData(cpuProfileDataWithTags);

      expect(
          controller.dataNotifier.value.cpuProfileRoot.profileMetaData.time
              .duration.inMicroseconds,
          equals(250));
      expect(
        controller.dataNotifier.value.cpuProfileRoot.toStringDeep(),
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
        controller.dataNotifier.value.cpuProfileRoot.toStringDeep(),
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
        controller.dataNotifier.value.cpuProfileRoot.toStringDeep(),
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
        controller.dataNotifier.value.cpuProfileRoot.toStringDeep(),
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
      expect(() {
        controller.dataNotifier.addListener(() {});
      }, throwsA(anything));
      expect(() {
        controller.selectedCpuStackFrameNotifier.addListener(() {});
      }, throwsA(anything));
      expect(() {
        controller.processingNotifier.addListener(() {});
      }, throwsA(anything));
    });
  });
}
