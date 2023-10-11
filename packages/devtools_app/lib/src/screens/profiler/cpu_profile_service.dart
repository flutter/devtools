// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../service/vm_flags.dart' as vm_flags;
import '../../shared/globals.dart';
import '../vm_developer/vm_service_private_extensions.dart';
import 'cpu_profile_model.dart';

/// Manages interactions between the Cpu Profiler and the VmService.
extension CpuProfilerExtension on VmService {
  Future<CpuProfilePair> getCpuProfile({
    required int startMicros,
    required int extentMicros,
  }) async {
    // Grab the value of this flag before doing asynchronous work.
    final vmDeveloperModeEnabled = preferences.vmDeveloperModeEnabled.value;

    final isolateId = serviceConnection
        .serviceManager.isolateManager.selectedIsolate.value!.id!;
    final cpuSamples =
        await serviceConnection.serviceManager.service!.getCpuSamples(
      isolateId,
      startMicros,
      extentMicros,
    );

    // If VM developer mode is enabled, getCpuSamples will also include code
    // profile details automatically (e.g., code stacks and a list of code
    // objects).
    //
    // If the samples contain a code stack, we should attach them to the
    // `CpuSample` objects.
    const kSamples = 'samples';
    const kCodeStack = '_codeStack';

    final rawSamples =
        (cpuSamples.json![kSamples] as List).cast<Map<String, dynamic>>();

    bool buildCodeProfile = false;
    if (rawSamples.isNotEmpty && rawSamples.first.containsKey(kCodeStack)) {
      // kCodeStack should not be present in the response if VM developer mode
      // is not enabled.
      assert(vmDeveloperModeEnabled);
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
    return serviceConnection.serviceManager.service!.clearCpuSamples(
      serviceConnection
          .serviceManager.isolateManager.selectedIsolate.value!.id!,
    );
  }

  Future<Response> setProfilePeriod(String value) {
    return serviceConnection.serviceManager.service!
        .setFlag(vm_flags.profilePeriod, value);
  }

  Future<Response> enableCpuProfiler() async {
    return await serviceConnection.serviceManager.service!
        .setFlag(vm_flags.profiler, 'true');
  }
}
