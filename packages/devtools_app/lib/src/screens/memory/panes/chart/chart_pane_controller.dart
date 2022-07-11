// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'memory_android_chart.dart';
import 'memory_events_pane.dart';
import 'memory_vm_chart.dart';

class MemoryChartPaneController {
  MemoryChartPaneController({
    required this.event,
    required this.vm,
    required this.android,
  });

  final EventChartController event;
  final VMChartController vm;
  final AndroidChartController android;

  void resetAll() {
    event.reset();
    vm.reset();
    android.reset();
  }

  /// Recomputes (attaches data to the chart) for either live or offline data
  /// source.
  void recomputeChartData() {
    resetAll();
    event.setupData();
    event.dirty = true;
    vm.setupData();
    vm.dirty = true;
    android.setupData();
    android.dirty = true;
  }
}
