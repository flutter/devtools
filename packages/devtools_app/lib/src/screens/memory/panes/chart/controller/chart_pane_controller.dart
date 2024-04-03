// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../../shared/globals.dart';
import '../../../framework/connected/memory_tracker.dart';
import '../../../shared/primitives/memory_timeline.dart';
import '../data/primitives.dart';
import '../widgets/memory_events_pane.dart';
import 'android_chart_controller.dart';
import 'vm_chart_controller.dart';

class MemoryChartPaneController extends DisposableController
    with AutoDisposeControllerMixin {
  MemoryChartPaneController({
    required this.event,
    required this.vm,
    required this.android,
  });

  final MemoryTimeline memoryTimeline = MemoryTimeline();
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

  final _paused = ValueNotifier<bool>(false);

  ValueListenable<bool> get paused => _paused;

  void pauseLiveFeed() {
    _paused.value = true;
  }

  void resumeLiveFeed() {
    _paused.value = false;
  }

  bool get isPaused => _paused.value;

  final isAndroidChartVisibleNotifier = ValueNotifier<bool>(false);

  void updateAndroidChartVisibility() {
    final bool isConnectedToAndroidAndAndroidEnabled =
        _isConnectedDeviceAndroid &&
            preferences.memory.androidCollectionEnabled.value;

    isAndroidChartVisibleNotifier.value = isConnectedToAndroidAndAndroidEnabled;
  }

  bool get _isConnectedDeviceAndroid {
    return serviceConnection.serviceManager.vm?.operatingSystem == 'android';
  }

  final StreamController<MemoryTracker?> memoryTrackerController =
      StreamController<MemoryTracker?>.broadcast();

  Stream<MemoryTracker?> get onMemory => memoryTrackerController.stream;

  MemoryTracker? memoryTracker;

  bool get hasStarted => memoryTracker != null;

  bool hasStopped = false;

  void stopTimeLine() {
    memoryTracker?.stop();
  }

  void _handleConnectionStart() {
    if (memoryTracker == null) {
      memoryTracker = MemoryTracker(memoryTimeline, this);
      memoryTracker!.start();
    }

    // Log Flutter extension events.
    // Note: We do not need to listen to event history here because we do not
    // have matching historical data about total memory usage.
    autoDisposeStreamSubscription(
      serviceConnection.serviceManager.service!.onExtensionEvent
          .listen((Event event) {
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
      }),
    );

    autoDisposeStreamSubscription(
      memoryTracker!.onChange.listen((_) {
        memoryTrackerController.add(memoryTracker);
      }),
    );
    autoDisposeStreamSubscription(
      memoryTracker!.onChange.listen((_) {
        memoryTrackerController.add(memoryTracker);
      }),
    );

    // TODO(terry): Used to detect stream being closed from the
    // memoryController dispose method.  Needed when a HOT RELOAD
    // will call dispose however, initState doesn't seem
    // to happen David is working on scaffolding.
    memoryTrackerController.stream.listen(
      (_) {},
      onDone: () {
        // Stop polling and reset memoryTracker.
        memoryTracker?.stop();
        memoryTracker = null;
      },
    );

    updateAndroidChartVisibility();
    addAutoDisposeListener(
      preferences.memory.androidCollectionEnabled,
      updateAndroidChartVisibility,
    );
  }

  void _handleConnectionStop() {
    memoryTracker?.stop();
    memoryTrackerController.add(memoryTracker);

    memoryTimeline.reset();
    hasStopped = true;
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
    _legendVisibleNotifier.dispose();
    _displayIntervalNotifier.dispose();
    _refreshCharts.dispose();
    event.dispose();
    vm.dispose();
    android.dispose();
    isAndroidChartVisibleNotifier.dispose();
  }
}
