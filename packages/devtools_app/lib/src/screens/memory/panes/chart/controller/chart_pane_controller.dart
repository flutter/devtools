// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../../../shared/globals.dart';
import '../../../../../shared/primitives/simple_items.dart';
import 'chart_connection.dart';
import 'chart_data.dart';
import 'charts/android_chart_controller.dart';
import 'charts/event_chart_controller.dart';
import 'charts/vm_chart_controller.dart';

class MemoryChartPaneController extends DisposableController
    with AutoDisposeControllerMixin {
  MemoryChartPaneController(this.mode, {bool? isDeviceAndroid})
      : assert(
          mode == DevToolsMode.connected || isDeviceAndroid != null,
          'If application is not connected, isDeviceAndroid must be provided.',
        ),
        data = ChartData(isDeviceAndroid: isDeviceAndroid) {
    unawaited(_init());
  }

  factory MemoryChartPaneController.fromJson(Map<String, dynamic> map) {
    // TODO(polina-c): implement, https://github.com/flutter/devtools/issues/6972
    return MemoryChartPaneController(
      DevToolsMode.offlineData,
      isDeviceAndroid: false,
    );
  }

  Map<String, dynamic> toJson() {
    // TODO(polina-c): implement, https://github.com/flutter/devtools/issues/6972
    return {};
  }

  DevToolsMode mode;

  final ChartData data;

  late final ChartConnection? _chartConnection =
      (mode == DevToolsMode.connected)
          ? ChartConnection(
              data.timeline,
              isAndroidChartVisible: isAndroidChartVisible,
            )
          : null;

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

  late final EventChartController event =
      EventChartController(data.timeline, paused: paused);
  late final VMChartController vm =
      VMChartController(data.timeline, paused: paused);
  late final AndroidChartController android = AndroidChartController(
    data.timeline,
    sharedLabels: vm.labelTimestamps,
    paused: paused,
  );

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
    final isAndroid = data.isDeviceAndroid ?? _chartConnection!.isDeviceAndroid;
    isAndroidChartVisible.value =
        isAndroid && preferences.memory.androidCollectionEnabled.value;
  }

  @override
  void dispose() {
    super.dispose();
    data.dispose();
    event.dispose();
    vm.dispose();
    android.dispose();
    isAndroidChartVisible.dispose();
    _chartConnection?.dispose();
  }
}
