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
  bool get isPaused => _paused.value;

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

  final StreamController<MemoryTracker?> _memoryTrackerController =
      StreamController<MemoryTracker?>.broadcast();

  @visibleForTesting
  Stream<MemoryTracker?> get onMemory => _memoryTrackerController.stream;

  MemoryTracker? _memoryTracker;

  bool get hasStarted => _memoryTracker != null;

  void stopTimeLine() => _memoryTracker?.stop();

  void _handleConnectionStart() {
    _memoryTracker ??= MemoryTracker(
      memoryTimeline,
      isAndroidChartVisible: isAndroidChartVisible,
      paused: paused,
    )..start();

    // Log Flutter extension events.
    // Note: We do not need to listen to event history here because we do not
    // have matching historical data about total memory usage.
    autoDisposeStreamSubscription(
      serviceConnection.serviceManager.service!.onExtensionEvent.listen(
        (Event event) {
          var extensionEventKind = event.extensionKind;
          String? customEventKind;
          if (MemoryTimeline.isCustomEvent(event.extensionKind!)) {
            extensionEventKind = MemoryTimeline.devToolsExtensionEvent;
            customEventKind =
                MemoryTimeline.customEventName(event.extensionKind!);
          }
          final jsonData = event.extensionData!.data.cast<String, Object>();
          // TODO(terry): Display events enabled in a settings page for now only these events.
          switch (extensionEventKind) {
            case 'Flutter.ImageSizesForFrame':
              memoryTimeline.addExtensionEvent(
                event.timestamp,
                event.extensionKind,
                jsonData,
              );
              break;
            case MemoryTimeline.devToolsExtensionEvent:
              memoryTimeline.addExtensionEvent(
                event.timestamp,
                MemoryTimeline.customDevToolsEvent,
                jsonData,
                customEventName: customEventKind,
              );
              break;
          }
        },
      ),
    );

    autoDisposeStreamSubscription(
      _memoryTracker!.onChange.listen((_) {
        _memoryTrackerController.add(_memoryTracker);
      }),
    );
    autoDisposeStreamSubscription(
      _memoryTracker!.onChange.listen((_) {
        _memoryTrackerController.add(_memoryTracker);
      }),
    );

    // TODO(terry): Used to detect stream being closed from the
    // memoryController dispose method.  Needed when a HOT RELOAD
    // will call dispose however, initState doesn't seem
    // to happen David is working on scaffolding.
    _memoryTrackerController.stream.listen(
      (_) {},
      onDone: () {
        // Stop polling and reset memoryTracker.
        _memoryTracker?.stop();
        _memoryTracker = null;
      },
    );

    _updateAndroidChartVisibility();
    addAutoDisposeListener(
      preferences.memory.androidCollectionEnabled,
      _updateAndroidChartVisibility,
    );
  }

  void _handleConnectionStop() {
    _memoryTracker?.stop();
    _memoryTrackerController.add(_memoryTracker);

    memoryTimeline.reset();
  }

  void startTimeline() {
    addAutoDisposeListener(serviceConnection.serviceManager.connectedState, () {
      if (serviceConnection.serviceManager.connectedState.value.connected) {
        _handleConnectionStart();
      } else {
        _handleConnectionStop();
      }
    });

    if (serviceConnection.serviceManager.connectedAppInitialized) {
      _handleConnectionStart();
    }
  }

  @override
  void dispose() {
    super.dispose();
    unawaited(_memoryTrackerController.close());
    _memoryTracker?.dispose();
    _legendVisibleNotifier.dispose();
    _displayInterval.dispose();
    _refreshCharts.dispose();
    event.dispose();
    vm.dispose();
    android.dispose();
    isAndroidChartVisible.dispose();
  }
}
