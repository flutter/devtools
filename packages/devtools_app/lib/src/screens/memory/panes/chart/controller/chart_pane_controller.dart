// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../../../shared/globals.dart';
import '../../../../../shared/primitives/simple_items.dart';
import '../../../shared/primitives/memory_timeline.dart';
import '../data/primitives.dart';
import 'android_chart_controller.dart';
import 'chart_connection.dart';
import 'event_chart_controller.dart';
import 'vm_chart_controller.dart';

class MemoryChartPaneController extends DisposableController
    with AutoDisposeControllerMixin {
  MemoryChartPaneController(this.mode, {this.isDeviceAndroid})
      : assert(
          mode == DevToolsMode.connected || isDeviceAndroid != null,
          'If application is not connected, isDeviceAndroid must be provided.',
        ) {
    unawaited(_init());
  }

  factory MemoryChartPaneController.fromJson(Map<String, dynamic> map) {
    // TODO(polina-c): implement, https://github.com/flutter/devtools/issues/6972
    return MemoryChartPaneController(
      DevToolsMode.offlineData,
      isDeviceAndroid: false,
    );
  }

  DevToolsMode mode;

  /// Wether device is android, if [mode] is not [DevToolsMode.connected].
  ///
  /// If [mode] is [DevToolsMode.connected], this value should be detected
  /// by [_chartConnection].
  final bool? isDeviceAndroid;

  Future<void> _init() async {
    _updateAndroidChartVisibility();
    if (mode == DevToolsMode.connected && isChartVisible.value) {
      await resume();
    }
    addAutoDisposeListener(
      preferences.memory.androidCollectionEnabled,
      _updateAndroidChartVisibility,
    );
  }

  Map<String, dynamic> toJson() {
    // TODO(polina-c): implement, https://github.com/flutter/devtools/issues/6972
    return {};
  }

  late final ChartConnection? _chartConnection =
      (mode == DevToolsMode.connected)
          ? ChartConnection(
              memoryTimeline,
              isAndroidChartVisible: isAndroidChartVisible,
            )
          : null;

  final MemoryTimeline memoryTimeline = MemoryTimeline();

  late final EventChartController event =
      EventChartController(memoryTimeline, paused: paused);
  late final VMChartController vm =
      VMChartController(memoryTimeline, paused: paused);
  late final AndroidChartController android = AndroidChartController(
    memoryTimeline,
    sharedLabels: vm.labelTimestamps,
    paused: paused,
  );

  ValueListenable<bool> get isLegendVisible => _legendVisibleNotifier;
  final _legendVisibleNotifier = ValueNotifier<bool>(true);
  bool toggleLegendVisibility() =>
      _legendVisibleNotifier.value = !_legendVisibleNotifier.value;

  ValueNotifier<bool> isChartVisible = preferences.memory.showChart;

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

  /// Default is to display default tick width based on width of chart of the collected
  /// data in the chart.
  final _displayInterval =
      ValueNotifier<ChartInterval>(ChartInterval.theDefault);

  set displayInterval(ChartInterval interval) {
    _displayInterval.value = interval;
  }

  ChartInterval get displayInterval => _displayInterval.value;

  ValueListenable<bool> get paused => _paused;
  final _paused = ValueNotifier<bool>(true);
  void pause() => _paused.value = true;
  Future<void> resume() async {
    if (!_paused.value) return;
    if (mode != DevToolsMode.connected) throw StateError('Not connected.');
    await _chartConnection!.maybeConnect();
    _paused.value = false;
  }

  final isAndroidChartVisible = ValueNotifier<bool>(false);

  void _updateAndroidChartVisibility() {
    final isAndroid = isDeviceAndroid ?? _chartConnection!.isDeviceAndroid;
    isAndroidChartVisible.value =
        isAndroid && preferences.memory.androidCollectionEnabled.value;
  }

  @override
  void dispose() {
    super.dispose();
    _legendVisibleNotifier.dispose();
    _displayInterval.dispose();
    event.dispose();
    vm.dispose();
    android.dispose();
    isAndroidChartVisible.dispose();
    _chartConnection?.dispose();
  }
}
