// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

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
    final advancedDeveloperModeEnabled =
        preferences.advancedDeveloperModeEnabled.value;

    final isolateId = serviceConnection
        .serviceManager
        .isolateManager
        .selectedIsolate
        .value!
        .id!;
    final cpuSamples = await serviceConnection.serviceManager.service!
        .getCpuSamples(isolateId, startMicros, extentMicros);

    // If advanced developer mode is enabled, getCpuSamples will also include
    // code profile details automatically (e.g., code stacks and a list of code
    // objects).
    //
    // If the samples contain a code stack, we should attach them to the
    // `CpuSample` objects.
    const kSamples = 'samples';
    const kCodeStack = '_codeStack';

    final rawSamples = (cpuSamples.json![kSamples] as List<Object?>)
        .cast<Map<String, Object?>>();

    bool buildCodeProfile = false;
    if (rawSamples.isNotEmpty && rawSamples.first.containsKey(kCodeStack)) {
      // `kCodeStack` should not be present in the response if advanced
      // developer mode is not enabled.
      assert(advancedDeveloperModeEnabled);
      buildCodeProfile = true;
      final samples = cpuSamples.samples!;
      for (int i = 0; i < samples.length; ++i) {
        final cpuSample = samples[i];
        final rawSample = rawSamples[i];
        final codeStack = (rawSample[kCodeStack] as List).cast<int>();
        cpuSample.setCodeStack(codeStack);
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

  Future<void> clearSamples() {
    return serviceConnection.serviceManager.service!.clearCpuSamples(
      serviceConnection
          .serviceManager
          .isolateManager
          .selectedIsolate
          .value!
          .id!,
    );
  }

  Future<Response> setProfilePeriod(String value) {
    return serviceConnection.serviceManager.service!.setFlag(
      vm_flags.profilePeriod,
      value,
    );
  }

  Future<Response> enableCpuProfiler() async {
    return await serviceConnection.serviceManager.service!.setFlag(
      vm_flags.profiler,
      'true',
    );
  }
}
