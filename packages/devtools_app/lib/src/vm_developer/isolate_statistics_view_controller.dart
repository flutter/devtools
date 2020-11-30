// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart' hide VmService;

import '../auto_dispose.dart';
import '../globals.dart';
import '../profiler/cpu_profile_controller.dart';
import '../vm_service_wrapper.dart';
import 'vm_service_private_extensions.dart';

class IsolateStatisticsViewController extends DisposableController
    with CpuProfilerControllerProviderMixin {
  IsolateStatisticsViewController() {
    // If the CPU profiler is enabled later, refresh the isolate data to get
    // the tag information.
    cpuProfilerController.profilerFlagNotifier.addListener(
      () => refresh(),
    );
    serviceManager.isolateManager.onSelectedIsolateChanged.listen((isolate) {
      switchToIsolate(isolate);
    });
    switchToIsolate(serviceManager.isolateManager.selectedIsolate);
  }

  VmServiceWrapper get _service => serviceManager.service;

  Isolate get isolate => _isolate;
  Isolate _isolate;

  ValueListenable<bool> get refreshing => _refreshing;
  final _refreshing = ValueNotifier<bool>(false);

  List<InstanceRef> get ports => UnmodifiableListView(_ports);
  List<InstanceRef> _ports = [];

  List<VMTag> get tags => UnmodifiableListView(_tags);
  List<VMTag> _tags = [];

  List<String> get serviceExtensions =>
      UnmodifiableListView(_serviceExtensions);
  List<String> _serviceExtensions = [];

  int get zoneCapacityHighWatermark => _zoneCapacityHighWatermark;
  int _zoneCapacityHighWatermark = 0;

  Future<void> refresh() async => await switchToIsolate(isolate);

  Future<void> switchToIsolate(IsolateRef isolateRef) async {
    _refreshing.value = true;

    // Retrieve updated isolate information and refresh the page.
    _isolate = await _service.getIsolate(isolateRef.id);
    _updateTagCounters(isolate);
    _updateZoneUsageData(isolate);
    _ports = (await _service.getPorts(_isolate.id)).ports;
    _serviceExtensions = isolate.extensionRPCs ?? [];
    _serviceExtensions.sort();
    _refreshing.value = false;
  }

  void _updateTagCounters(Isolate isolate) {
    // Tag counters aren't available if the profiler is disabled.
    if (isolate.tagCounters != null) {
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
          VMTag(name, percentages[name] / totalTickCount),
      ];
    }
  }

  void _updateZoneUsageData(Isolate isolate) {
    final currentWatermark =
        isolate.threads.fold(0, (p, t) => p + t.zoneHighWatermark);
    if (currentWatermark > _zoneCapacityHighWatermark) {
      _zoneCapacityHighWatermark = currentWatermark;
    }
  }
}

/// Data class representing a single VM tag and its runtime percentage.
class VMTag {
  VMTag(this.name, this.percentage);
  final String name;
  final double percentage;
}
