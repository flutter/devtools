// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../globals.dart';
import '../utils.dart';
import 'network_controller.dart';

class NetworkService {
  NetworkService(this.networkController);

  final NetworkController networkController;

  /// Enables or disables HTTP logging for all isolates.
  Future<void> enableHttpRequestLogging(bool state) async {
    assert(state == !networkController.httpRecordingNotifier.value);
    await serviceManager.service.forEachIsolate((isolate) async {
      final future = serviceManager.service.setHttpEnableTimelineLogging(
        isolate.id,
        state,
      );
      // The above call won't complete immediately if the isolate is paused, so
      // give up waiting after 500ms. However, the call _will_ complete eventually
      // if the isolate is eventually resumed.
      await timeout(future, 500);
    });
    networkController.httpRecordingNotifier.value = state;
  }

  /// Updates the last refresh time to the current time.
  ///
  /// If `alreadyRecording` is true it's unclear when the last refresh time
  /// would have occurred, so the refresh time is not updated. Otherwise,
  /// `NetworkController.lastProfileRefreshMicros` is updated to the current
  /// timeline timestamp.
  ///
  /// Returns the current timestamp.
  Future<int> updateLastRefreshTime({bool alreadyRecording = false}) async {
    // Set the current timeline time as the time of the last refresh.
    final timestamp = await serviceManager.service.getVMTimelineMicros();

    if (!alreadyRecording) {
      // Only include HTTP requests issued after the current time.
      networkController.lastProfileRefreshMicros = timestamp.timestamp;
    }
    return timestamp.timestamp;
  }

  /// Force refreshes the HTTP requests logged to the timeline.
  Future<void> refreshHttpRequests() async {
    final timestamp = await serviceManager.service.getVMTimelineMicros();
    final timeline = await serviceManager.service.getVMTimeline(
      timeOriginMicros: networkController.lastProfileRefreshMicros,
      timeExtentMicros:
          timestamp.timestamp - networkController.lastProfileRefreshMicros,
    );
    networkController.lastProfileRefreshMicros = timestamp.timestamp;
    networkController.processHttpTimelineEvents(timeline);
  }

  /// Determines if HTTP logging is already enabled on at least one isolate and
  /// updates the recording state accordingly.
  ///
  /// If at least one isolate is already logging, this method will enable logging
  /// on all isolates and enable recording for [NetworkScreen].
  Future<bool> initializeRecordingState() async {
    bool enabled = false;
    await serviceManager.service.forEachIsolate(
      (isolate) async {
        final future =
            serviceManager.service.getHttpEnableTimelineLogging(isolate.id);
        // The above call won't complete immediately if the isolate is paused,
        // so give up waiting after 500ms.
        final state = await timeout(future, 500);
        if (state != null && state.enabled) {
          enabled = true;
        }
      },
    );

    if (enabled) {
      await networkController.startRecording(alreadyRecording: true);
      networkController.httpRecordingNotifier.value = enabled;
    }
    return enabled;
  }
}
