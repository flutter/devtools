// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../profiler/cpu_profile_model.dart';
import '../profiler/cpu_profiler_controller.dart';
import '../ui/fake_flutter/fake_flutter.dart';
import '../utils.dart';

class PerformanceController {
  final CpuProfilerController cpuProfilerController = CpuProfilerController();

  CpuProfileData get cpuProfileData => cpuProfilerController.dataNotifier.value;

  /// Notifies that the timeline is currently being recorded.
  ValueListenable get recordingNotifier => _recordingNotifier;
  final _recordingNotifier = ValueNotifier<bool>(false);

  final int _profileStartMicros = 0;

  Future<void> startRecording() async {
    await clear();
    _recordingNotifier.value = true;

    // TODO(kenz): once [getVMTimelineMicros] is available, we can get the
    // current timestamp here and set [_profileStartMicros] equal to it. We will
    // use [_profileStartMicros] for [startMicros] in the [getCpuProfile]
    // request. For backwards compatibility, we will let start micros default to
    // 0.
  }

  Future<void> stopRecording() async {
    await cpuProfilerController.pullAndProcessProfile(
      startMicros: _profileStartMicros,
      // Using [maxJsInt] as [extentMicros] for the getCpuProfile requests will
      // give us all cpu samples we have available
      extentMicros: maxJsInt,
    );
    _recordingNotifier.value = false;
  }

  Future<void> clear() async {
    await cpuProfilerController.clear();
  }
}
