// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';
import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profile_model.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

void main() {
  test('GenerateFromCpuSamplesBenchmark Test', () async {
    final benchmark = GenerateFromCpuSamplesBenchmark();
    final score = await benchmark.measure();

    expect(score, lessThan(40000)); // 40 ms
  });
}

class GenerateFromCpuSamplesBenchmark extends AsyncBenchmarkBase {
  GenerateFromCpuSamplesBenchmark()
    : super('CpuProfileData.generateFromCpuSamples');

  late final vm_service.CpuSamples cpuSamples;

  static Future<void> main() async {
    await GenerateFromCpuSamplesBenchmark().report();
  }

  @override
  Future<void> setup() async {
    setGlobal(
      ServiceConnectionManager,
      FakeServiceConnectionManager(
        service: FakeServiceManager.createFakeService(),
      ),
    );
    final cpuSamplesFile = File(
      'test/test_infra/test_data/cpu_profiler/cpu_samples.json',
    );
    final cpuSamplesJson = jsonDecode(cpuSamplesFile.readAsStringSync());
    cpuSamples = vm_service.CpuSamples.parse(cpuSamplesJson)!;
  }

  @override
  Future<void> run() async {
    await CpuProfileData.generateFromCpuSamples(
      isolateId: 'test-isolate',
      cpuSamples: cpuSamples,
    );
  }
}
