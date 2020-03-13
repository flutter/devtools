// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/profiler/cpu_profile_controller.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_testing/support/cpu_profile_test_data.dart';
import 'package:test/test.dart';

import 'support/mocks.dart';

void main() {
  group('CpuProfileController', () {
    CpuProfilerController controller;
    FakeServiceManager fakeServiceManager;

    setUp(() {
      fakeServiceManager = FakeServiceManager(useFakeService: true);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      controller = CpuProfilerController();
    });

    Future<void> pullProfileAndSelectFrame() async {
      await controller.pullAndProcessProfile(startMicros: 0, extentMicros: 100);
      controller.selectCpuStackFrame(testStackFrame);
      expect(
        controller.data.value,
        isNot(equals(CpuProfilerController.baseStateCpuProfileData)),
      );
      expect(
        controller.selectedCpuStackFrame.value,
        equals(testStackFrame),
      );
    }

    test('pullAndProcessProfile', () async {
      expect(
        controller.data.value,
        equals(CpuProfilerController.baseStateCpuProfileData),
      );
      expect(controller.processing.value, false);

      // [startMicros] and [extentMicros] are arbitrary for testing.
      await controller.pullAndProcessProfile(startMicros: 0, extentMicros: 100);
      expect(
        controller.data.value,
        isNot(equals(CpuProfilerController.baseStateCpuProfileData)),
      );
      expect(controller.processing.value, false);

      await controller.clear();
      expect(
        controller.data.value,
        equals(CpuProfilerController.baseStateCpuProfileData),
      );
    });

    test('selectCpuStackFrame', () async {
      expect(
        controller.data.value.selectedStackFrame,
        isNull,
      );
      expect(controller.selectedCpuStackFrame.value, isNull);
      controller.selectCpuStackFrame(testStackFrame);
      expect(
        controller.data.value.selectedStackFrame,
        equals(testStackFrame),
      );
      expect(
        controller.selectedCpuStackFrame.value,
        equals(testStackFrame),
      );

      await controller.clear();
      expect(controller.selectedCpuStackFrame.value, isNull);
    });

    test('reset', () async {
      await pullProfileAndSelectFrame();
      controller.reset();
      expect(
        controller.data.value,
        equals(CpuProfilerController.baseStateCpuProfileData),
      );
      expect(controller.selectedCpuStackFrame.value, isNull);
      expect(controller.processing.value, isFalse);
    });

    test('disposes', () {
      controller.dispose();
      expect(() {
        controller.data.addListener(() {});
      }, throwsA(anything));
      expect(() {
        controller.selectedCpuStackFrame.addListener(() {});
      }, throwsA(anything));
      expect(() {
        controller.processing.addListener(() {});
      }, throwsA(anything));
    });
  });
}
