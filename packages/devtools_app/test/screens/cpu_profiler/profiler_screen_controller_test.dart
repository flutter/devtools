// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profiler_controller.dart';
import 'package:devtools_app/src/shared/feature_flags.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../../test_infra/test_data/cpu_profiler/cpu_profile.dart';

void main() {
  group('ProfilerScreenController', () {
    late ProfilerScreenController controller;

    setUp(() {
      FeatureFlags.memoryObserver = true;
      final fakeServiceConnection = FakeServiceConnectionManager(
        service: FakeServiceManager.createFakeService(
          cpuSamples: CpuSamples.parse(goldenCpuSamplesJson),
          resolvedUriMap: goldenResolvedUriMap,
        ),
      );
      final app = fakeServiceConnection.serviceManager.connectedApp!;
      when(app.isFlutterAppNow).thenReturn(true);

      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      setGlobal(OfflineDataController, OfflineDataController());
      setGlobal(PreferencesController, PreferencesController());
      controller = ProfilerScreenController();
    });

    test('start and stop recording', () async {
      expect(controller.recordingNotifier.value, isFalse);
      await controller.startRecording();
      expect(controller.recordingNotifier.value, isTrue);
      await controller.stopRecording();
      expect(controller.recordingNotifier.value, isFalse);
    });

    test('disposes', () {
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

    test('releaseMemory', () async {
      FeatureFlags.memoryObserver = true;
      await controller.cpuProfilerController.loadAllSamples();
      expect(controller.cpuProfilerController.dataNotifier.value, isNotNull);
      expect(
        controller.cpuProfilerController.dataNotifier.value,
        isNot(CpuProfilerController.baseStateCpuProfileData),
      );
      await controller.releaseMemory();
      expect(
        controller.cpuProfilerController.dataNotifier.value,
        CpuProfilerController.baseStateCpuProfileData,
      );
      FeatureFlags.memoryObserver = false;
    });
  });
}
