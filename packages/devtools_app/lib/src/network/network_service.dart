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

  Future<void> _forEachIsolate(Future Function(IsolateRef) callback) async {
    final vm = await serviceManager.service.getVM();
    final futures = <Future>[];
    for (final isolate in vm.isolates) {
      futures.add(callback(isolate));
    }
    await Future.wait(futures);
  }

  /// Enables or disables HTTP logging for all isolates.
  Future<void> enableHttpRequestLogging(bool state) async {
    assert(state == !networkController.httpRecordingNotifier.value);
    await _forEachIsolate((isolate) async {
      final future = serviceManager.service.setHttpEnableTimelineLogging(
        isolate.id,
        state,
      );
      // The above call won't complete if the isolate is paused, so give up
      // after 500ms.
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
    await _forEachIsolate(
      (isolate) async {
        final future =
            serviceManager.service.getHttpEnableTimelineLogging(isolate.id);
        // The above call won't complete if the isolate is paused, so give up
        // after 500ms.
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
