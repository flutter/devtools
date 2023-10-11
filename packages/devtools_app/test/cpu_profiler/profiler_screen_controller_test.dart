// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('ProfilerScreenController', () {
    late ProfilerScreenController controller;
    final fakeServiceConnection = FakeServiceConnectionManager();
    when(fakeServiceConnection.serviceManager.connectedApp!.isFlutterAppNow)
        .thenReturn(false);

    setUp(() {
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      setGlobal(OfflineModeController, OfflineModeController());
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
      expect(
        () {
          controller.recordingNotifier.addListener(() {});
        },
        throwsA(anything),
      );

      expect(
        () {
          controller.cpuProfilerController.dataNotifier.addListener(() {});
        },
        throwsA(anything),
      );

      expect(
        () {
          controller.cpuProfilerController.selectedCpuStackFrameNotifier
              .addListener(() {});
        },
        throwsA(anything),
      );
    });
  });
}
