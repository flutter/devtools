// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../shared/globals.dart';
import '../../shared/primitives/utils.dart';
import 'network_controller.dart';

class NetworkService {
  NetworkService(this.networkController);

  final NetworkController networkController;

  /// Updates the last refresh time to the current time.
  ///
  /// If [alreadyRecordingHttp] is true it's unclear when the last refresh time
  /// would have occurred, so the refresh time is not updated. Otherwise,
  /// [NetworkController.lastRefreshMicros] is updated to the current
  /// timeline timestamp.
  ///
  /// Returns the current timestamp.
  Future<int> updateLastRefreshTime({bool alreadyRecordingHttp = false}) async {
    // Set the current timeline time as the time of the last refresh.
    final timestampObj =
        await serviceConnection.serviceManager.service!.getVMTimelineMicros();

    final timestamp = timestampObj.timestamp!;
    if (!alreadyRecordingHttp) {
      // Only include HTTP requests issued after the current time.
      networkController.lastRefreshMicros = timestamp;
    }
    return timestamp;
  }

  /// Force refreshes the HTTP requests logged to the timeline as well as any
  /// recorded Socket traffic.
  Future<void> refreshNetworkData() async {
    if (serviceConnection.serviceManager.service == null) return;
    final timestampObj =
        await serviceConnection.serviceManager.service!.getVMTimelineMicros();
    final timestamp = timestampObj.timestamp!;
    final sockets = await _refreshSockets(timestamp);
    List<HttpProfileRequest>? httpRequests;
    httpRequests = await _refreshHttpProfile();
    networkController.lastRefreshMicros = timestamp;
    networkController.processNetworkTraffic(
      sockets: sockets,
      httpRequests: httpRequests,
    );
  }

  Future<List<HttpProfileRequest>> _refreshHttpProfile() async {
    final service = serviceConnection.serviceManager.service;
    if (service == null) return [];

    final requests = <HttpProfileRequest>[];
    await service.forEachIsolate((isolate) async {
      final request = await service.getHttpProfileWrapper(
        isolate.id!,
        updatedSince: networkController.lastRefreshMicros,
      );
      requests.addAll(request.requests);
    });
    return requests;
  }

  Future<void> _clearHttpProfile() async {
    final service = serviceConnection.serviceManager.service;
    if (service == null) return;
    await service.forEachIsolate((isolate) async {
      final future = service.clearHttpProfileWrapper(isolate.id!);
      // The above call won't complete immediately if the isolate is paused, so
      // give up waiting after 500ms. However, the call will complete eventually
      // if the isolate is eventually resumed.
      // TODO(jacobr): detect whether the isolate is paused using the vm
      // service and handle this case gracefully rather than timing out.
      await timeout(future, 500);
    });
  }

  Future<List<SocketStatistic>> _refreshSockets(int lastRefreshMicros) async {
    final service = serviceConnection.serviceManager.service;
    if (service == null) return [];
    final sockets = <SocketStatistic>[];
    await service.forEachIsolate((isolate) async {
      final socketProfile = await service.getSocketProfileWrapper(isolate.id!);
      sockets.addAll(socketProfile.sockets);
    });

    // TODO(https://github.com/flutter/devtools/issues/5057):
    // Filter lastrefreshMicros inside [service.getSocketProfile] instead.
    return sockets
        .where(
          (element) =>
              element.startTime > lastRefreshMicros ||
              (element.endTime ?? 0) > lastRefreshMicros ||
              (element.lastReadTime ?? 0) > lastRefreshMicros ||
              (element.lastWriteTime ?? 0) > lastRefreshMicros,
        )
        .toList();
  }

  Future<void> _clearSocketProfile() async {
    final service = serviceConnection.serviceManager.service;
    if (service == null) return;
    await service.forEachIsolate((isolate) async {
      final isolateId = isolate.id!;
      final socketProfilingAvailable =
          await service.isSocketProfilingAvailableWrapper(isolateId);
      if (socketProfilingAvailable) {
        final future = service.clearSocketProfileWrapper(isolateId);
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
    final service = serviceConnection.serviceManager.service;
    if (service == null) return;
    await service.forEachIsolate((isolate) async {
      final isolateId = isolate.id!;
      final socketProfilingAvailable =
          await service.isSocketProfilingAvailableWrapper(isolateId);
      if (socketProfilingAvailable) {
        final future = service.socketProfilingEnabledWrapper(isolateId, state);
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
    await _clearHttpProfile();
  }
}
