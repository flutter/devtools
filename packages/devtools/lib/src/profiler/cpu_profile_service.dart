// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import '../globals.dart';
import '../profiler/cpu_profile_model.dart';
import '../profiler/cpu_profile_protocol.dart';

// TODO(kenzie): remove once we no longer need stub data to build the
// performance UI.
/// When true, we will store the first cpu profile response we see as
/// [debugStubCpuProfile].
///
/// This is a hack to aid in developing the performance page.
bool debugStoreCpuProfile = false;
CpuProfileData debugStubCpuProfile;

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
    // TODO(kenzie): remove this once we no longer need stub data to build the
    // performance UI.
    if (debugStoreCpuProfile && debugStubCpuProfile == null) {
      debugStubCpuProfile = CpuProfileData.parse(response.json);
      CpuProfileProtocol().processData(debugStubCpuProfile);
    }

    return CpuProfileData.parse(response.json);
  }
}
