// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../profiler/cpu_profile_model.dart';
import '../profiler/cpu_profile_service.dart';
import '../profiler/cpu_profile_transformer.dart';
import '../utils.dart';

class PerformanceController {
  final CpuProfilerService cpuProfilerService = CpuProfilerService();

  final CpuProfileTransformer cpuProfileTransformer = CpuProfileTransformer();

  /// Processed cpu profile data from the recorded performance profile.
  CpuProfileData cpuProfileData;

  Timer timer;

  bool get recording => _recording;

  bool _recording = false;

  final int _profileStartMicros = 0;

  Future<void> startRecording() async {
    await reset();
    _recording = true;

    // TODO(kenzie): once [getVMTimelineMicros] is available, we can get the
    // current timestamp here and set [_profileStartMicros] equal to it. We will
    // use [_profileStartMicros] for [startMicros] in the [getCpuProfile]
    // request. For backwards compatibility, we will let start micros default to
    // 0.
  }

  Future<void> stopRecording() async {
    _recording = false;

    cpuProfileData = await cpuProfilerService.getCpuProfile(
      startMicros: _profileStartMicros,
      // Using [maxJsInt] as [extentMicros] for the getCpuProfile requests will
      // give us all cpu samples we have available
      extentMicros: maxJsInt,
    );
  }

  Future<void> reset() async {
    cpuProfileData = null;
    await cpuProfilerService.clearCpuProfile();
  }
}
