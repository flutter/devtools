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
import 'event_chart_controller.dart';
import 'memory_tracker.dart';
import 'vm_chart_controller.dart';

/// Connection between chart and application.
///
/// The connection consists of listeners to events from vm and
/// ongoing requests to vm service for current memory usage.
///
/// When user pauses the chart, the data is still collected.
///
/// Does not fail in case of accidental disconnect.
///
/// All interactions between chart and vm are initiated by this class.
/// So, if this class is not instantiated, the interaction does not happen.
class _ChartConnection extends DisposableController
    with AutoDisposeControllerMixin {
  _ChartConnection(this._memoryTracker);

  final MemoryTracker _memoryTracker;
  Timer? _pollingTimer;
  bool _connected = false;

  late final isDeviceAndroid =
      serviceConnection.serviceManager.vm?.operatingSystem == 'android';

  Future<void> maybeConnect() async {
    if (_connected) return;
    await serviceConnection.serviceManager.onServiceAvailable;
    autoDisposeStreamSubscription(
      serviceConnection.serviceManager.service!.onExtensionEvent
          .listen(_memoryTracker.onMemoryData),
    );
    autoDisposeStreamSubscription(
      serviceConnection.serviceManager.service!.onGCEvent
          .listen(_memoryTracker.onGCEvent),
    );
    await _onPoll();
    _connected = true;
  }

  Future<void> _onPoll() async {
    _pollingTimer = null;
    await _memoryTracker.pollMemory();
    _pollingTimer = Timer(chartUpdateDelay, _onPoll);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}

class MemoryChartPaneController extends DisposableController
    with AutoDisposeControllerMixin {
  MemoryChartPaneController(this.mode, {this.isDeviceAndroid})
      : assert(
          mode == DevToolsMode.connected || isDeviceAndroid != null,
          'If application is not connected, isDeviceAndroid must be provided.',
        ) {
    unawaited(_init());
  }

  factory MemoryChartPaneController.parse(Map<String, dynamic> map) {
    // TODO(polina-c): implement, https://github.com/flutter/devtools/issues/6972
    return MemoryChartPaneController(
      DevToolsMode.offlineData,
      isDeviceAndroid: false,
    );
  }

  DevToolsMode mode;

  /// Wether device is android, if [mode] is not [DevToolsMode.connected].
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

  Map<String, dynamic> prepareForOffline() {
    // TODO(polina-c): implement, https://github.com/flutter/devtools/issues/6972
    return {};
  }

  late final _ChartConnection? _chartConnection =
      (mode == DevToolsMode.connected)
          ? _ChartConnection(_memoryTracker)
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

  ValueListenable get refreshCharts => _refreshCharts;
  final _refreshCharts = ValueNotifier<int>(0);

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

  late final MemoryTracker _memoryTracker = MemoryTracker(
    memoryTimeline,
    isAndroidChartVisible: isAndroidChartVisible,
  );

  bool get hasStarted => paused.value;

  @override
  void dispose() {
    super.dispose();
    _legendVisibleNotifier.dispose();
    _displayInterval.dispose();
    _refreshCharts.dispose();
    event.dispose();
    vm.dispose();
    android.dispose();
    isAndroidChartVisible.dispose();
    _chartConnection?.dispose();
  }
}
