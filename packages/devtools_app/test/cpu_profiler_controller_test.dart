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
