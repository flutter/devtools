// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../../../shared/globals.dart';
import '../../../../../shared/utils.dart';
import '../../../shared/primitives/memory_timeline.dart';
import '../data/primitives.dart';
import 'memory_tracker.dart';

enum ChartConnectionState {
  notInitialized,
  connected,
  stopped,
}

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
class ChartConnection extends DisposableController
    with AutoDisposeControllerMixin {
  ChartConnection(this.timeline, {required this.isAndroidChartVisible});

  final MemoryTimeline timeline;
  final ValueListenable<bool> isAndroidChartVisible;

  late final MemoryTracker _memoryTracker = MemoryTracker(
    timeline,
    isAndroidChartVisible: isAndroidChartVisible,
  );

  DebounceTimer? _polling;

  ChartConnectionState state = ChartConnectionState.notInitialized;

  void _stopConnection() {
    _polling?.cancel();
    _polling = null;
    // We use state to declare disconnection.
    // We cannot use nullness of _polling to check disconnection, because there is async gap in
    // `maybeInitialize` when state is already initialized, but _polling is still null.
    state = ChartConnectionState.stopped;
  }

  late bool isDeviceAndroid;

  /// True if still connected to application.
  ///
  /// If disconnected, stops interaction with app, declares disconnected state and returns false.
  bool _checkConnection() {
    assert(state != ChartConnectionState.notInitialized);
    if (state == ChartConnectionState.stopped) return false;

    // If connection is up and running, return true.
    if (serviceConnection.serviceManager.connectedState.value.connected) {
      return true;
    }

    // Otherwise stop connection and return false.
    _stopConnection();
    return false;
  }

  Future<void> maybeInitialize() async {
    if (state != ChartConnectionState.notInitialized) return;
    state = ChartConnectionState.connected;
    if (!_checkConnection()) {
      isDeviceAndroid = false;
      return;
    }

    await serviceConnection.serviceManager.onServiceAvailable;

    isDeviceAndroid =
        serviceConnection.serviceManager.vm?.operatingSystem == 'android';

    addAutoDisposeListener(
      serviceConnection.serviceManager.connectedState,
      _checkConnection,
    );

    autoDisposeStreamSubscription(
      serviceConnection.serviceManager.service!.onExtensionEvent
          .listen(_memoryTracker.onMemoryData),
    );

    autoDisposeStreamSubscription(
      serviceConnection.serviceManager.service!.onGCEvent
          .listen(_memoryTracker.onGCEvent),
    );

    _polling = DebounceTimer.periodic(
      chartUpdateDelay,
      () async {
        if (!_checkConnection()) return;
        try {
          await _memoryTracker.pollMemory();
        } catch (e) {
          if (_checkConnection()) rethrow;
        }
      },
    );
  }

  @override
  void dispose() {
    _polling?.dispose();
    _polling = null;
    super.dispose();
  }
}
