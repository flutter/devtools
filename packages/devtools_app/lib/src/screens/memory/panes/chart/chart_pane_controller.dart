// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import 'memory_android_chart.dart';
import 'memory_events_pane.dart';
import 'memory_vm_chart.dart';
import 'primitives.dart';

class MemoryChartPaneController extends DisposableController
    with AutoDisposeControllerMixin {
  MemoryChartPaneController({
    required this.event,
    required this.vm,
    required this.android,
  });

  final EventChartController event;
  final VMChartController vm;
  final AndroidChartController android;

  ValueListenable<bool> get legendVisibleNotifier => _legendVisibleNotifier;

  final _legendVisibleNotifier = ValueNotifier<bool>(true);

  bool toggleLegendVisibility() =>
      _legendVisibleNotifier.value = !_legendVisibleNotifier.value;

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

  ValueListenable get refreshCharts => _refreshCharts;

  final _refreshCharts = ValueNotifier<int>(0);

  /// Default is to display default tick width based on width of chart of the collected
  /// data in the chart.
  final _displayIntervalNotifier =
      ValueNotifier<ChartInterval>(ChartInterval.theDefault);

  set displayInterval(ChartInterval interval) {
    _displayIntervalNotifier.value = interval;
  }

  ChartInterval get displayInterval => _displayIntervalNotifier.value;

  @override
  void dispose() {
    super.dispose();
    _legendVisibleNotifier.dispose();
    _displayIntervalNotifier.dispose();
    _refreshCharts.dispose();
    event.dispose();
    vm.dispose();
    android.dispose();
  }
}
