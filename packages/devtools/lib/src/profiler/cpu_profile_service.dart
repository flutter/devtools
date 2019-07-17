// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import '../globals.dart';
import '../profiler/cpu_profile_model.dart';

/// Default period at which the VM will collect CPU samples.
///
/// This value is applied to the profile_period VM flag.
const int defaultSamplePeriod = 250;

/// Manages interactions between the Cpu Profiler and the VmService.
class CpuProfilerService {
  Future<CpuProfileData> getCpuProfile({
    @required int startMicros,
    @required int extentMicros,
  }) async {
    final Response response =
        await serviceManager.service.getCpuProfileTimeline(
      serviceManager.isolateManager.selectedIsolate.id,
      startMicros,
      extentMicros,
    );
    return CpuProfileData.parse(response.json);
  }

  Future<Success> clearCpuProfile() async {
    return serviceManager.service
        .clearCpuProfile(serviceManager.isolateManager.selectedIsolate.id);
  }
}
