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
      assert(offlineData!.isDeviceAndroid != null);
      data = offlineData!;
      recomputeChartData();
    }

    _calculateAndroidChartVisibility();
    addAutoDisposeListener(
      preferences.memory.androidCollectionEnabled,
      _calculateAndroidChartVisibility,
    );

    await _onChartVisibilityChanged();
    addAutoDisposeListener(
      preferences.memory.showChart,
      () => unawaited(_onChartVisibilityChanged()),
    );

    if (mode == DevToolsMode.offlineData) {
      _paused.value = false;
      data.timeline.notifyAboutAllSamples();
      recomputeChartData();
      print('!!! sent notifyAboutAllSamples and recomputeChartData');
    }
    _initialized.complete();
    print('!!! MemoryChartPaneController init');
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

  /// Connects when chart is first time expanded.
  ///
  /// If chart is already connected, does nothing.
  /// Return true if connection was setup.
  Future<bool> maybeConnect() async {
    if (!_paused.value) return false;
    if (mode != DevToolsMode.connected) return false;
    await _chartConnection!.maybeConnect();
    return true;
  }

  final isAndroidChartVisible = ValueNotifier<bool>(false);
  void _calculateAndroidChartVisibility() {
    data.isDeviceAndroid ??= _chartConnection!.isDeviceAndroid;
    isAndroidChartVisible.value = data.isDeviceAndroid! &&
        preferences.memory.androidCollectionEnabled.value;
  }

  ValueListenable<bool> isChartVisible = preferences.memory.showChart;
  Future<void> _onChartVisibilityChanged() async {
    if (isChartVisible.value) {
      if (await maybeConnect()) resume();
    }
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
