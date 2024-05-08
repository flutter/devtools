// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../../../shared/globals.dart';
import '../../../../../shared/utils.dart';
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
class ChartVmConnection extends DisposableController
    with AutoDisposeControllerMixin {
  ChartVmConnection(this.timeline, {required this.isAndroidChartVisible});

  final MemoryTimeline timeline;
  final ValueListenable<bool> isAndroidChartVisible;

  late final MemoryTracker _memoryTracker = MemoryTracker(
    timeline,
    isAndroidChartVisible: isAndroidChartVisible,
  );

  bool initialized = false;

  DebounceTimer? _polling;

  late final bool isDeviceAndroid;

  /// Initializes the connection.
  ///
  /// This method should be called without async gap after validation that
  /// the application is still connected.
  void init() {
    if (initialized) return;

    assert(serviceConnection.serviceManager.connectedState.value.connected);

    isDeviceAndroid =
        serviceConnection.serviceManager.vm?.operatingSystem == 'android';

    addAutoDisposeListener(serviceConnection.serviceManager.connectedState, () {
      final connected =
          serviceConnection.serviceManager.connectedState.value.connected;
      if (!connected) {
        _polling?.cancel();
      }
    });

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
        if (!serviceConnection.serviceManager.connectedState.value.connected) {
          _polling?.cancel();
          return;
        }
        try {
          await _memoryTracker.pollMemory();
        } catch (e, stack) {
          if (serviceConnection.serviceManager.connectedState.value.connected) {
            print('!!!!');
            print(e);
            print(stack);
            rethrow;
          }
        }
      },
    );

    initialized = true;
  }

  @override
  void dispose() {
    _polling?.cancel();
    _polling?.dispose();
    _polling = null;
    super.dispose();
  }
}
