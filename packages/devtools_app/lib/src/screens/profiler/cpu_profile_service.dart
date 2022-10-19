// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../service/vm_flags.dart' as vm_flags;
import '../../service/vm_service_wrapper.dart';
import '../../shared/globals.dart';
import '../vm_developer/vm_service_private_extensions.dart';
import 'cpu_profile_model.dart';

/// Manages interactions between the Cpu Profiler and the VmService.
extension CpuProfilerExtension on VmServiceWrapper {
  Future<CpuProfilePair> getCpuProfile({
    required int startMicros,
    required int extentMicros,
  }) async {
    final isolateId = serviceManager.isolateManager.selectedIsolate.value!.id!;
    final cpuSamples = await serviceManager.service!.getCpuSamples(
      isolateId,
      startMicros,
      extentMicros,
    );

    const kSamples = 'samples';
    const kCodeStack = '_codeStack';

    final rawSamples =
        (cpuSamples.json![kSamples] as List).cast<Map<String, dynamic>>();

    bool buildCodeProfile = false;
    // If the samples contain a code stack, we should attach them to the
    // `CpuSample` objects.
    if (rawSamples.first.containsKey(kCodeStack)) {
      buildCodeProfile = true;
      final samples = cpuSamples.samples!;
      for (int i = 0; i < samples.length; ++i) {
        final cpuSample = samples[i];
        final rawSample = rawSamples[i];
        cpuSample.setCodeStack(rawSample[kCodeStack].cast<int>());
      }
    }

    final functionProfile = await CpuProfileData.generateFromCpuSamples(
      isolateId: isolateId,
      cpuSamples: cpuSamples,
    );
    CpuProfileData? codeProfile;
    if (buildCodeProfile) {
      codeProfile = await CpuProfileData.generateFromCpuSamples(
        isolateId: isolateId,
        cpuSamples: cpuSamples,
        buildCodeTree: true,
      );
    }
    return CpuProfilePair(
      functionProfile: functionProfile,
      codeProfile: codeProfile,
    );
  }

  Future clearSamples() {
    return serviceManager.service!.clearCpuSamples(
      serviceManager.isolateManager.selectedIsolate.value!.id!,
    );
  }

  Future<dynamic> setProfilePeriod(String value) {
    return serviceManager.service!.setFlag(vm_flags.profilePeriod, value);
  }

  Future<dynamic> enableCpuProfiler() async {
    return await serviceManager.service!.setFlag(vm_flags.profiler, 'true');
  }
}
