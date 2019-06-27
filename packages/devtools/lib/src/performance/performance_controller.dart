// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../profiler/cpu_profile_model.dart';
import '../profiler/cpu_profile_service.dart';

class PerformanceController {
  final CpuProfilerService cpuProfilerService = CpuProfilerService();

  /// Final cpu profile data after merging the recorded profiles.
  CpuProfileData cpuProfileData;

  /// Cpu profiles recorded on an interval during the time between starting and
  /// stopping the recording.
  List<CpuProfileData> recordedProfiles = [];

  Timer timer;

  bool get recording => _recording;

  bool _recording = false;

  void startRecording() async {
    reset();
    _recording = true;

    // TODO(kenzie): ensure this code is backwards compatible. The first request
    // will start at 0 and end at int max (2^52).
    // TODO(kenzie): uncomment this code once getVMTimelineMicros is available.
//    const int timerDuration = 100;
//    int startMicros =
//      (await serviceManager.service.getVMTimelineMicros()).timestamp;
//    timer = Timer.periodic(
//      const Duration(microseconds: timerDuration),
//      (_) async {
//        recordedProfiles.add(await cpuProfilerService.getCpuProfile(
//          startMicros: startMicros,
//          extentMicros: timerDuration,
//        ));
//        // Set [startMicros] to the end of the current profile. This will be the
//        // start time in the request for the next sample.
//        startMicros = cpuProfileData.time.end.inMicroseconds;
//      },
//    );
  }

  void stopRecording() {
    // TODO(kenzie): uncomment this once getVMTimelineMicros is available.
//    timer.cancel();
    _recording = false;
  }

  void reset() {
    cpuProfileData = null;
    recordedProfiles.clear();
  }

  void mergeRecordedProfiles() {
    // TODO(kenzie): merge profiles from [recordedProfiles] and set
    // cpuProfileData. We could do something smart here where we merge in the
    // down time between `getCpuProfile` requests.

    // Temporarily set equal to stub data.
    cpuProfileData = debugStubCpuProfile;
  }
}
