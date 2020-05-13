// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../profiler/cpu_profile_controller.dart';
import '../profiler/cpu_profile_model.dart';
import '../utils.dart';

class PerformanceController with CpuProfilerControllerProviderMixin {
  CpuProfileData get cpuProfileData => cpuProfilerController.dataNotifier.value;

  /// Notifies that a CPU profile is currently being recorded.
  ValueListenable get recordingNotifier => _recordingNotifier;
  final _recordingNotifier = ValueNotifier<bool>(false);

  final int _profileStartMicros = 0;

  Future<void> startRecording() async {
    await clear();
    _recordingNotifier.value = true;
  }

  Future<void> stopRecording() async {
    _recordingNotifier.value = false;
    await cpuProfilerController.pullAndProcessProfile(
      startMicros: _profileStartMicros,
      // Using [maxJsInt] as [extentMicros] for the getCpuProfile requests will
      // give us all cpu samples we have available
      extentMicros: maxJsInt,
    );
  }

  Future<void> clear() async {
    await cpuProfilerController.clear();
  }

  void dispose() {
    _recordingNotifier.dispose();
    cpuProfilerController.dispose();
  }
}
