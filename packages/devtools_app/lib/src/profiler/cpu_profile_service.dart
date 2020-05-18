// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import '../globals.dart';
import '../profiler/cpu_profile_model.dart';
import '../vm_flags.dart' as vm_flags;

/// Manages interactions between the Cpu Profiler and the VmService.
class CpuProfilerService {
  Future<CpuProfileData> getCpuProfile({
    @required int startMicros,
    @required int extentMicros,
  }) async {
    return await serviceManager.service.getCpuProfileTimeline(
      serviceManager.isolateManager.selectedIsolate.id,
      startMicros,
      extentMicros,
    );
  }

  /// Notifies that the vm profiler flag has changed.
  ValueNotifier<Flag> get profilerFlagNotifier =>
      serviceManager.vmFlagManager.flag(vm_flags.profiler);

  ValueNotifier<Flag> get profileGranularityFlagNotifier =>
      serviceManager.vmFlagManager.flag(vm_flags.profilePeriod);

  Future clearCpuSamples() {
    return serviceManager.service
        .clearCpuSamples(serviceManager.isolateManager.selectedIsolate.id);
  }

  Future<dynamic> setProfilePeriod(String value) {
    return serviceManager.service.setFlag(vm_flags.profilePeriod, value);
  }

  Future<dynamic> enableCpuProfiler() async {
    return await serviceManager.service.setFlag(vm_flags.profiler, 'true');
  }
}
