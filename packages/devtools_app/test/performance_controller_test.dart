// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/performance/performance_controller.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:test/test.dart';

import 'support/mocks.dart';

void main() {
  group('PerformanceController', () {
    PerformanceController controller;
    FakeServiceManager fakeServiceManager;

    setUp(() {
      fakeServiceManager = FakeServiceManager();
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      controller = PerformanceController();
    });

    test('start and stop recording', () async {
      expect(controller.recordingNotifier.value, isFalse);
      await controller.startRecording();
      expect(controller.recordingNotifier.value, isTrue);
      await controller.stopRecording();
      expect(controller.recordingNotifier.value, isFalse);
    });

    test('disposes', () async {
      controller.dispose();
      expect(() {
        controller.recordingNotifier.addListener(() {});
      }, throwsA(anything));

      expect(() {
        controller.cpuProfilerController.dataNotifier.addListener(() {});
      }, throwsA(anything));

      expect(() {
        controller.cpuProfilerController.selectedCpuStackFrameNotifier
            .addListener(() {});
      }, throwsA(anything));
    });
  });
}
