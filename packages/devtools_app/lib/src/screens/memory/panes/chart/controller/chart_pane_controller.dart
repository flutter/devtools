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
  MemoryChartPaneController(this.mode, {ChartData? data})
      : assert(
          mode == DevToolsMode.connected ||
              (mode == DevToolsMode.offlineData &&
                  data != null &&
                  data.isDeviceAndroid != null),
          '$mode, $data, ${data?.isDeviceAndroid}',
        ) {
    unawaited(_init(data));
  }

  DevToolsMode mode;

  late final ChartData data;

  late final ChartConnection? _chartConnection =
      (mode == DevToolsMode.connected)
          ? ChartConnection(
              data.timeline,
              isAndroidChartVisible: isAndroidChartVisible,
            )
          : null;

  Future<void> get initialized => _initialized.future;
  final _initialized = Completer<void>();

  Future<void> _init(ChartData? offlineData) async {
    assert(!_initialized.isCompleted);
    if (mode == DevToolsMode.connected) {
      data = ChartData(mode: DevToolsMode.connected);
    } else {
      data = offlineData!;
      _paused.value = false;
      recomputeChartData();
    }

    await _onChartVisibilityChanged();
    addAutoDisposeListener(
      isChartVisible,
      () => unawaited(_onChartVisibilityChanged()),
    );

    _maybeCalculateAndroidChartVisibility();
    addAutoDisposeListener(
      preferences.memory.androidCollectionEnabled,
      _maybeCalculateAndroidChartVisibility,
    );

    _initialized.complete();
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
  void resume() {
    assert(mode == DevToolsMode.connected && _chartConnection != null);
    _paused.value = false;
  }

  /// Establishes the chart connection when the chart is expanded for the first time.
  ///
  /// Returns true if the chart was already connected or the connection was established.
  Future<bool> maybeConnect() async {
    if (!_paused.value) return false;
    if (mode != DevToolsMode.connected) return false;
    await _chartConnection!.maybeInitialize();
    return true;
  }

  final isAndroidChartVisible = ValueNotifier<bool>(false);
  void _maybeCalculateAndroidChartVisibility() {
    if (!isChartVisible.value) return;
    data.isDeviceAndroid ??= _chartConnection!.isDeviceAndroid;
    isAndroidChartVisible.value = data.isDeviceAndroid! &&
        preferences.memory.androidCollectionEnabled.value;
  }

  ValueListenable<bool> get isChartVisible => preferences.memory.showChart;
  Future<void> _onChartVisibilityChanged() async {
    if (isChartVisible.value && await maybeConnect()) resume();
    _maybeCalculateAndroidChartVisibility();
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
