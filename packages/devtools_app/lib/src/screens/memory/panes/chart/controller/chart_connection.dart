// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../../../shared/globals.dart';
import '../../../shared/primitives/memory_timeline.dart';
import '../data/primitives.dart';
import 'memory_tracker.dart';

typedef _AsyncVoidCallback = Future<void> Function();

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

  Timer? _pollingTimer;
  bool _connected = false;

  /// If true, the connection to application was lost.
  bool _disconnected = false;

  late final isDeviceAndroid = _isDevToolsCurrentlyConnected()
      ? serviceConnection.serviceManager.vm?.operatingSystem == 'android'
      : false;

  /// True if DevTools is in connected mode and the connection to the app is alive.
  bool _isDevToolsCurrentlyConnected() =>
      // Theoretically it should be enough to check only connectedState.value.connected,
      // but practically these values are not always in sync and, if at least
      // on of them means disconnection this class consider the connection as lost,
      // and stops interaction with it.
      !offlineDataController.showingOfflineData.value &&
      serviceConnection.serviceManager.connectedState.value.connected &&
      serviceConnection.serviceManager.connectedApp != null;

  Future<void> maybeConnect() async {
    if (_connected || _disconnected) return;
    _connected = true;
    await _runSafely(() async {
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
    });
  }

  Future<void> _onPoll() async {
    assert(_connected);
    if (_disconnected) return;
    await _runSafely(() async {
      _pollingTimer = null;
      await _memoryTracker.pollMemory();
      _pollingTimer = Timer(chartUpdateDelay, _onPoll);
    });
  }

  /// Run callback resiliently to disconnect.
  Future<void> _runSafely(_AsyncVoidCallback callback) async {
    if (_disconnected) return;
    try {
      await callback();
    } catch (e) {
      if (_isDevToolsCurrentlyConnected()) {
        rethrow;
      } else {
        _disconnected = true;
        _pollingTimer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
