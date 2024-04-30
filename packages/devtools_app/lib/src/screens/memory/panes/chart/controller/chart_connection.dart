// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../../../shared/globals.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../shared/primitives/memory_timeline.dart';
import '../data/primitives.dart';
import 'memory_tracker.dart';

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

  RateLimiter? _polling;

  /// If completed, this instance was connected to the application.
  final Completer<void> _initialized = Completer();

  void _stopConnection() {
    _polling?.dispose();
    _polling = null;
    cancelStreamSubscriptions();
    cancelListeners();
  }

  // True if connection was started and then stopped.
  bool get _isConnectionStopped {
    return _initialized.isCompleted);
    return _polling?. == false;
  }

  late bool isDeviceAndroid;

  /// True if DevTools is in connected mode.
  ///
  /// If DevTools is in offline mode, stops connection and returns false.
  bool _checkConnection() {
    assert(_initialized.isCompleted);
    if (_isConnectionStopped) return false;

    // If connection is up and running, return true.
    if (!offlineDataController.showingOfflineData.value &&
        serviceConnection.serviceManager.connectedState.value.connected) {
      return true;
    }

    // Otherwise stop connection and return false.
    _stopConnection();
    return false;
  }

  Future<void> maybeInitialize() async {
    if (_initialized.isCompleted) return;
    _initialized.complete();
    if (!_checkConnection()) return;

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

    _startPolling();
  }

  void _startPolling() {
    assert(_initialized.isCompleted);
    if (!_checkConnection()) return;
    _polling = RateLimiter(
      chartUpdatesPerSecond,
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
    // Not nulling out timer, because we need timer to be not null and inactive
    // for `_isConnectionStopped` to return true.
    _polling?.dispose();
    super.dispose();
  }
}
