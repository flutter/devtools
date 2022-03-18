// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../primitives/utils.dart';
import '../../shared/globals.dart';
import '../../shared/version.dart';
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
    final timestampObj = await serviceManager.service!.getVMTimelineMicros();

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
    if (serviceManager.service == null) return;

    final timestampObj = await serviceManager.service!.getVMTimelineMicros();
    final timestamp = timestampObj.timestamp!;
    final sockets = await _refreshSockets();
    List<HttpProfileRequest>? httpRequests;
    Timeline? timeline;
    final service = serviceManager.service!;
    if (await service.isDartIoVersionSupported(
      supportedVersion: SemanticVersion(major: 1, minor: 6),
      isolateId: serviceManager.isolateManager.selectedIsolate.value!.id!,
    )) {
      httpRequests = await _refreshHttpProfile();
    } else {
      timeline = await service.getVMTimeline(
        timeOriginMicros: networkController.lastRefreshMicros,
        timeExtentMicros: timestamp - networkController.lastRefreshMicros,
      );
    }
    networkController.lastRefreshMicros = timestamp;
    networkController.processNetworkTraffic(
      timeline: timeline,
      sockets: sockets,
      httpRequests: httpRequests,
    );
  }

  Future<List<HttpProfileRequest>> _refreshHttpProfile() async {
    final service = serviceManager.service;
    if (service == null) return [];

    final requests = <HttpProfileRequest>[];
    await service.forEachIsolate((isolate) async {
      final request = await service.getHttpProfile(
        isolate.id!,
        updatedSince: networkController.lastRefreshMicros,
      );
      requests.addAll(request.requests);
    });
    return requests;
  }

  Future<void> _clearHttpProfile() async {
    final service = serviceManager.service;
    if (service == null) return;
    await service.forEachIsolate((isolate) async {
      final future = service.clearHttpProfile(isolate.id!);
      // The above call won't complete immediately if the isolate is paused, so
      // give up waiting after 500ms. However, the call will complete eventually
      // if the isolate is eventually resumed.
      // TODO(jacobr): detect whether the isolate is paused using the vm
      // service and handle this case gracefully rather than timing out.
      await timeout(future, 500);
    });
  }

  Future<List<SocketStatistic>> _refreshSockets() async {
    final service = serviceManager.service;
    if (service == null) return [];
    final sockets = <SocketStatistic>[];
    await service.forEachIsolate((isolate) async {
      final socketProfile = await service.getSocketProfile(isolate.id!);
      sockets.addAll(socketProfile.sockets);
    });
    return sockets;
  }

  Future<void> _clearSocketProfile() async {
    final service = serviceManager.service;
    if (service == null) return;
    await service.forEachIsolate((isolate) async {
      final isolateId = isolate.id!;
      final socketProfilingAvailable =
          await service.isSocketProfilingAvailable(isolateId);
      if (socketProfilingAvailable) {
        final future = service.clearSocketProfile(isolateId);
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
    final service = serviceManager.service;
    if (service == null) return;
    await service.forEachIsolate((isolate) async {
      final isolateId = isolate.id!;
      final socketProfilingAvailable =
          await service.isSocketProfilingAvailable(isolateId);
      if (socketProfilingAvailable) {
        final future = service.socketProfilingEnabled(isolateId, state);
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
