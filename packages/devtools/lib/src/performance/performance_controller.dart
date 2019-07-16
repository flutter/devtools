// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import '../profiler/cpu_profile_model.dart';
import '../profiler/cpu_profile_processor.dart';
import '../profiler/cpu_profile_service.dart';

class PerformanceController {
  final CpuProfilerService cpuProfilerService = CpuProfilerService();

  final CpuProfileProcessor cpuProfileProcessor = CpuProfileProcessor();

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

    // 2^52 is the max int for dart2js. Using this as [extentMicros] for the
    // getCpuProfile requests will give us all cpu samples we have available.
    final maxJsInt = pow(2, 52);

    cpuProfileData = await cpuProfilerService.getCpuProfile(
      startMicros: _profileStartMicros,
      extentMicros: maxJsInt,
    );
  }

  Future<void> reset() async {
    cpuProfileData = null;
    await cpuProfilerService.clearCpuProfile();
  }
}
