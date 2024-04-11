// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../../shared/globals.dart';
import '../../../../../shared/primitives/simple_items.dart';
import '../../../shared/primitives/memory_timeline.dart';
import '../data/primitives.dart';
import 'android_chart_controller.dart';
import 'event_chart_controller.dart';
import 'memory_tracker.dart';
import 'vm_chart_controller.dart';

/// States of chart connection.
///
/// In lifetime of one chart controller the states are changed in the following order:
/// [notStarted] -> [connected] -> [disconnected].
/// Reconnection does not happen.
enum _ConnectionState {
  notStarted,
  connected,
  disconnected,
}

typedef _MemoryEventHandler = void Function(Event);

/// Manages connection between chart and application.
///
/// Configures the connection first time when it is needed.
/// Pauses / resumes handling memory events when user pauses / resumes chart.
/// Handles accidental disconnect.
/// It is not chart controller's responsibility to handle reconnection and graceful
/// interaction with user. It just should not fail when connection is lost.
///
/// When connection is lost, [paused] turns to true.
class _ChartConnectionController extends DisposableController {
  _ChartConnectionController({required this.onData});

  final _MemoryEventHandler onData;
  _ConnectionState _state = _ConnectionState.notStarted;

  bool get paused => _paused;
  bool _paused = true;
  Future<void> setPaused(bool value) async {
    if (_paused == value) return;
    _paused = value;
    if (!_paused) await _maybeConnect();
  }

  Future<void> _maybeConnect() async {
    if (_state != _ConnectionState.notStarted) return;
    await serviceConnection.serviceManager.onServiceAvailable;

    _state = _ConnectionState.connected;
  }
}

class MemoryChartPaneController extends DisposableController
    with AutoDisposeControllerMixin {
  MemoryChartPaneController(this.mode);

  factory MemoryChartPaneController.parse(Map<String, dynamic> map) {
    // TODO(polina-c): implement, https://github.com/flutter/devtools/issues/6972
    return MemoryChartPaneController(DevToolsMode.offlineData);
  }

  DevToolsMode mode;

  Map<String, dynamic> prepareForOffline() {
    // TODO(polina-c): implement, https://github.com/flutter/devtools/issues/6972
    return {};
  }

  late final _ChartConnectionController? _chartConnection =
      mode == DevToolsMode.connected
          ? _ChartConnectionController(onData: _onMemoryData)
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
  final _paused = ValueNotifier<bool>(false);
  void pauseLiveFeed() => _paused.value = true;
  void resumeLiveFeed() => _paused.value = false;

  final isAndroidChartVisible = ValueNotifier<bool>(false);

  void _updateAndroidChartVisibility() {
    final bool isConnectedToAndroidAndAndroidEnabled =
        _isConnectedDeviceAndroid &&
            preferences.memory.androidCollectionEnabled.value;

    isAndroidChartVisible.value = isConnectedToAndroidAndAndroidEnabled;
  }

  bool get _isConnectedDeviceAndroid {
    return serviceConnection.serviceManager.vm?.operatingSystem == 'android';
  }

  late final MemoryTracker _memoryTracker = MemoryTracker(
    memoryTimeline,
    isAndroidChartVisible: isAndroidChartVisible,
    paused: paused,
  );

  bool get hasStarted => !paused.value;

  void _onConnect() {
    _memoryTracker.start();

    // Log Flutter extension events.
    // Note: We do not need to listen to event history here because we do not
    // have matching historical data about total memory usage.
    autoDisposeStreamSubscription(
      serviceConnection.serviceManager.service!.onExtensionEvent
          .listen(_onMemoryData),
    );

    _updateAndroidChartVisibility();
    addAutoDisposeListener(
      preferences.memory.androidCollectionEnabled,
      _updateAndroidChartVisibility,
    );
  }

  void _onMemoryData(Event data) {
    var extensionEventKind = data.extensionKind;
    String? customEventKind;
    if (MemoryTimeline.isCustomEvent(data.extensionKind!)) {
      extensionEventKind = MemoryTimeline.devToolsExtensionEvent;
      customEventKind = MemoryTimeline.customEventName(data.extensionKind!);
    }
    final jsonData = data.extensionData!.data.cast<String, Object>();
    // TODO(terry): Display events enabled in a settings page for now only these events.
    switch (extensionEventKind) {
      case 'Flutter.ImageSizesForFrame':
        memoryTimeline.addExtensionEvent(
          data.timestamp,
          data.extensionKind,
          jsonData,
        );
        break;
      case MemoryTimeline.devToolsExtensionEvent:
        memoryTimeline.addExtensionEvent(
          data.timestamp,
          MemoryTimeline.customDevToolsEvent,
          jsonData,
          customEventName: customEventKind,
        );
        break;
    }
  }

  void _onDisconnect() {
    _memoryTracker.stop();
    memoryTimeline.reset();
  }

  void startTimeline() {
    addAutoDisposeListener(serviceConnection.serviceManager.connectedState, () {
      if (serviceConnection.serviceManager.connectedState.value.connected) {
        _onConnect();
      } else {
        _onDisconnect();
      }
    });

    if (serviceConnection.serviceManager.connectedAppInitialized) {
      _onConnect();
    }
  }

  @override
  void dispose() {
    super.dispose();
    _memoryTracker.dispose();
    _legendVisibleNotifier.dispose();
    _displayInterval.dispose();
    _refreshCharts.dispose();
    event.dispose();
    vm.dispose();
    android.dispose();
    isAndroidChartVisible.dispose();
  }
}
