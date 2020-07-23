// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../globals.dart';
import '../utils.dart';
import 'network_controller.dart';

class NetworkService {
  NetworkService(this.networkController);

  final NetworkController networkController;

  /// Updates the last refresh time to the current time.
  ///
  /// If [alreadyRecording] is true it's unclear when the last refresh time
  /// would have occurred, so the refresh time is not updated. Otherwise,
  /// [NetworkController.lastRefreshMicros] is updated to the current
  /// timeline timestamp.
  ///
  /// Returns the current timestamp.
  Future<int> updateLastRefreshTime({bool alreadyRecording = false}) async {
    // Set the current timeline time as the time of the last refresh.
    final timestamp = await serviceManager.service.getVMTimelineMicros();

    if (!alreadyRecording) {
      // Only include HTTP requests issued after the current time.
      networkController.lastRefreshMicros = timestamp.timestamp;
    }
    return timestamp.timestamp;
  }

  /// Force refreshes the HTTP requests logged to the timeline as well as any
  /// recorded Socket traffic.
  Future<void> refreshNetworkData() async {
    if (serviceManager.service == null) return;

    final timestamp = await serviceManager.service.getVMTimelineMicros();
    final sockets = await _refreshSockets();
    final timeline = await serviceManager.service.getVMTimeline(
      timeOriginMicros: networkController.lastRefreshMicros,
      timeExtentMicros:
          timestamp.timestamp - networkController.lastRefreshMicros,
    );
    networkController.lastRefreshMicros = timestamp.timestamp;
    networkController.processNetworkTraffic(
      timeline: timeline,
      sockets: sockets,
    );
  }

  /// Determines if HTTP logging is already enabled on at least one isolate and
  /// updates the recording state accordingly.
  ///
  /// If at least one isolate is already logging, this method will enable logging
  /// on all isolates and enable recording for [NetworkScreen].
  Future<bool> initializeRecordingState() async {
    // TODO(jacobr): this method does not properly handle isolates that are
    // restarted.
    // TODO(kenz): should we be checking if socket profiling has started? There is
    // not currently a method we can call that returns this value.
    bool enabled = false;
    await serviceManager.service.forEachIsolate(
      (isolate) async {
        // TODO(bkonyi): perform VM service version check.
        final httpFuture =
            serviceManager.service.getHttpEnableTimelineLogging(isolate.id);
        // The above call won't complete immediately if the isolate is paused,
        // so give up waiting after 500ms.
        final state = await timeout(httpFuture, 500);
        if (state != null && state.enabled) {
          enabled = true;
        }
      },
    );

    if (enabled) {
      await networkController.startRecording(alreadyRecording: true);
    }
    return enabled;
  }

  Future<List<SocketStatistic>> _refreshSockets() async {
    final sockets = <SocketStatistic>[];
    await serviceManager.service.forEachIsolate((isolate) async {
      final socketProfile =
          await serviceManager.service.getSocketProfile(isolate.id);
      sockets.addAll(socketProfile.sockets);
    });
    return sockets;
  }

  Future<void> _clearSocketProfile() async {
    await serviceManager.service.forEachIsolate((isolate) async {
      final socketProfilingAvailable =
          await serviceManager.service.isSocketProfilingAvailable(isolate.id);
      if (socketProfilingAvailable) {
        final future = serviceManager.service.clearSocketProfile(isolate.id);
        // The above call won't complete immediately if the isolate is paused, so
        // give up waiting after 500ms. However, the call will complete eventually
        // if the isolate is eventually resumed.
        // TODO(jacobr): detect whether the isolate is paused using the vm
        // service and handle this case gracefully rather than timing out.
        await timeout(future, 500);
      }
    });
  }

  /// Enables or disables Socket profiling for all isolates.
  Future<void> toggleSocketProfiling(bool state) async {
    await serviceManager.service.forEachIsolate((isolate) async {
      final socketProfilingAvailable =
          await serviceManager.service.isSocketProfilingAvailable(isolate.id);
      if (socketProfilingAvailable) {
        Future future;
        if (state) {
          future = serviceManager.service.startSocketProfiling(isolate.id);
        } else {
          future = serviceManager.service.pauseSocketProfiling(isolate.id);
        }
        // The above call won't complete immediately if the isolate is paused, so
        // give up waiting after 500ms. However, the call will complete eventually
        // if the isolate is eventually resumed.
        // TODO(jacobr): detect whether the isolate is paused using the vm
        // service and handle this case gracefully rather than timing out.
        await timeout(future, 500);
      }
    });
  }

  Future<void> clearData() async {
    await updateLastRefreshTime();
    await _clearSocketProfile();
  }
}
