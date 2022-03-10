// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart' hide VmService;

import '../../primitives/auto_dispose.dart';
import '../../service/vm_service_wrapper.dart';
import '../../shared/globals.dart';
// ignore: import_of_legacy_library_into_null_safe
import '../profiler/cpu_profile_controller.dart';
import 'vm_service_private_extensions.dart';

class IsolateStatisticsViewController extends DisposableController
    with AutoDisposeControllerMixin {
  IsolateStatisticsViewController() {
    // If the CPU profiler is enabled later, refresh the isolate data to get
    // the tag information.
    cpuProfilerController.profilerFlagNotifier?.addListener(
      () => refresh(),
    );

    addAutoDisposeListener(serviceManager.isolateManager.selectedIsolate, () {
      switchToIsolate(serviceManager.isolateManager.selectedIsolate.value!);
    });
    switchToIsolate(serviceManager.isolateManager.selectedIsolate.value!);
  }

  final cpuProfilerController = CpuProfilerController();

  VmServiceWrapper get _service => serviceManager.service!;

  Isolate? get isolate => _isolate;
  Isolate? _isolate;

  ValueListenable<bool> get refreshing => _refreshing;
  final _refreshing = ValueNotifier<bool>(false);

  List<InstanceRef> get ports => UnmodifiableListView(_ports);
  List<InstanceRef> _ports = [];

  List<VMTag> get tags => UnmodifiableListView(_tags);
  List<VMTag> _tags = [];

  List<String> get serviceExtensions =>
      UnmodifiableListView(_serviceExtensions);
  List<String> _serviceExtensions = [];

  Future<void> refresh() async => await switchToIsolate(isolate!);

  Future<void> switchToIsolate(IsolateRef isolateRef) async {
    _refreshing.value = true;

    final isolateId = isolateRef.id!;
    // Retrieve updated isolate information and refresh the page.
    _isolate = await _service.getIsolate(isolateId);
    final isolate = _isolate!;
    _updateTagCounters(isolate);
    _ports = (await _service.getPorts(isolateId)).ports!;
    _serviceExtensions = isolate.extensionRPCs ?? [];
    _serviceExtensions.sort();
    _refreshing.value = false;
  }

  void _updateTagCounters(Isolate isolate) {
    // Tag counters aren't available if the profiler is disabled.
    // Tag counters are incremented when a profiler tick occurs within a
    // given tag's scope in the VM. These raw counts are reported here and
    // need to be processed.
    final tagCounters = isolate.tagCounters;
    final names = tagCounters['names'];
    final List<int> counters = tagCounters['counters'].cast<int>();
    final percentages = <String, double>{};
    int totalTickCount = 0;
    for (int i = 0; i < counters.length; ++i) {
      // Ignore tags with empty counts.
      if (counters[i] == 0) continue;
      percentages[names[i]] = counters[i].toDouble();
      totalTickCount += counters[i];
    }
    _tags = <VMTag>[
      for (final name in percentages.keys)
        VMTag(name, percentages[name]! / totalTickCount),
    ];
  }
}

/// Data class representing a single VM tag and its runtime percentage.
class VMTag {
  VMTag(this.name, this.percentage);
  final String name;
  final double percentage;
}
