// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

import '../globals.dart';
import '../vm_flags.dart' as vm_flags;
import '../vm_service_wrapper.dart';
import 'cpu_profile_model.dart';

/// Manages interactions between the Cpu Profiler and the VmService.
extension CpuProfilerExtension on VmServiceWrapper {
  Future<CpuProfileData> getCpuProfile({
    @required int startMicros,
    @required int extentMicros,
  }) async {
    return await serviceManager.service.getCpuProfileTimeline(
      serviceManager.isolateManager.selectedIsolate.value.id,
      startMicros,
      extentMicros,
    );
  }

  Future clearSamples() {
    return serviceManager.service.clearCpuSamples(
        serviceManager.isolateManager.selectedIsolate.value.id);
  }

  Future<dynamic> setProfilePeriod(String value) {
    return serviceManager.service.setFlag(vm_flags.profilePeriod, value);
  }

  Future<dynamic> enableCpuProfiler() async {
    return await serviceManager.service.setFlag(vm_flags.profiler, 'true');
  }
}
