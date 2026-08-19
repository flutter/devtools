// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/service.dart';
import 'package:vm_service/vm_service.dart';

import '../../shared/globals.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/utils/utils.dart';
import 'network_controller.dart';

class NetworkService {
  NetworkController get networkController =>
      screenControllers.lookup<NetworkController>();

  /// Tracks the VM timeline timestamp (microseconds) that the HTTP profile was
  /// last retrieved for a given isolate ID.
  ///
  /// These values are passed to `getHttpProfile` as `updatedSince`, which must
  /// use the VM's monotonic timeline clock — not wall-clock time.
  final lastHttpDataRefreshTimePerIsolate = <String, int>{};

  /// Tracks the time (microseconds since epoch) that the WebSocket profile was
  /// last retrieved for a given isolate ID.
  final lastWebSocketDataRefreshTimePerIsolate = <String, int>{};

  /// Updates the last Socket data refresh time to the current time.
  ///
  /// If [alreadyRecordingSocketData] is true, it's unclear when the last
  /// refresh time would have occurred, so the refresh time is not updated.
  /// Otherwise, [NetworkController.lastSocketDataRefreshMicros] is updated to
  /// the current timeline timestamp.
  ///
  /// Returns the current timeline timestamp.
  Future<int> updateLastSocketDataRefreshTime({
    bool alreadyRecordingSocketData = false,
  }) async {
    // Set the current timeline time as the time of the last refresh.
    final timestampObj = await serviceConnection.serviceManager.service!
        .getVMTimelineMicros();

    final timestamp = timestampObj.timestamp!;
    if (!alreadyRecordingSocketData) {
      // Only include Socket requests issued after the current time.
      networkController.lastSocketDataRefreshMicros = timestamp;
    }
    return timestamp;
  }

  /// Updates the last HTTP data refresh time to the current VM timeline time.
  ///
  /// If [alreadyRecordingHttp] is true it's unclear when the last refresh time
  /// would have occurred, so the refresh time is not updated. Otherwise,
  /// [lastHttpDataRefreshTimePerIsolate] is updated to the current VM timeline
  /// timestamp for each known isolate.
  ///
  /// Wall-clock time must not be used here: `getHttpProfile`'s `updatedSince`
  /// expects the VM timeline clock. A wall-clock value would filter out all
  /// subsequent requests.
  Future<void> updateLastHttpDataRefreshTime({
    bool alreadyRecordingHttp = false,
  }) async {
    if (!alreadyRecordingHttp) {
      final service = serviceConnection.serviceManager.service;
      if (service == null) return;
      final timestamp = (await service.getVMTimelineMicros()).timestamp!;
      for (final isolateId in lastHttpDataRefreshTimePerIsolate.keys.toList()) {
        lastHttpDataRefreshTimePerIsolate[isolateId] = timestamp;
      }
    }
  }

  /// Updates the last WebSocket data refresh time to the current time.
  ///
  /// WebSocket profiling is controlled by HttpClient.enableTimelineLogging,
  /// so this timestamp follows the HTTP timeline logging lifecycle.
  void updateLastWebSocketDataRefreshTime({
    bool alreadyRecordingWebSocket = false,
  }) {
    if (!alreadyRecordingWebSocket) {
      final now = DateTime.now().microsecondsSinceEpoch;
      for (final isolateId
          in lastWebSocketDataRefreshTimePerIsolate.keys.toList()) {
        lastWebSocketDataRefreshTimePerIsolate[isolateId] = now;
      }
    }
  }

  /// Force refreshes the HTTP requests logged to the timeline as well as any
  /// recorded Socket traffic.
  ///
  /// This method calls [cancelledCallback] after each async gap to ensure that
  /// this operation has not been cancelled during the async gap.
  Future<void> refreshNetworkData({
    DebounceCancelledCallback? cancelledCallback,
  }) async {
    if (serviceConnection.serviceManager.service == null) return;
    try {
      final timestampObj = await serviceConnection.serviceManager.service!
          .getVMTimelineMicros();
      if (cancelledCallback?.call() ?? false) return;

      final timestamp = timestampObj.timestamp!;
      final sockets = await _refreshSockets();
      if (cancelledCallback?.call() ?? false) return;

      networkController.lastSocketDataRefreshMicros = timestamp;

      final webSockets = await _refreshWebSocketProfile();
      if (cancelledCallback?.call() ?? false) return;

      List<HttpProfileRequest>? httpRequests;
      httpRequests = await _refreshHttpProfile();
      if (cancelledCallback?.call() ?? false) return;

      networkController.processNetworkTraffic(
        sockets: sockets,
        httpRequests: httpRequests,
        webSockets: webSockets,
      );
    } on RPCError catch (e) {
      if (!e.isServiceDisposedError) {
        // Swallow exceptions related to trying to interact with an
        // already-disposed service connection. Otherwise, rethrow.
        rethrow;
      }
    }
  }

  Future<List<HttpProfileRequest>> _refreshHttpProfile() async {
    final service = serviceConnection.serviceManager.service;
    if (service == null) return [];

    final requests = <HttpProfileRequest>[];
    await service.forEachIsolate((isolate) async {
      final request = await service.getHttpProfileWrapper(
        isolate.id!,
        updatedSince: DateTime.fromMicrosecondsSinceEpoch(
          lastHttpDataRefreshTimePerIsolate.putIfAbsent(
            isolate.id!,
            // If a new isolate has spawned, request all HTTP requests from the
            // start of time when retrieving the first profile.
            () => 0,
          ),
        ),
      );
      requests.addAll(request.requests);
      // Update the last request time using the timestamp from the HTTP profile
      // instead of DateTime.now() to avoid missing events due to the delay
      // between the last profile creation in the target process and the call
      // to DateTime.now() here.
      lastHttpDataRefreshTimePerIsolate[isolate.id!] =
          request.timestamp.microsecondsSinceEpoch;
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

  Future<List<WebSocketConnection>> _refreshWebSocketProfile() async {
    final service = serviceConnection.serviceManager.service;
    if (service == null) return const [];

    final connections = <WebSocketConnection>[];

    await service.forEachIsolate((isolate) async {
      final isolateId = isolate.id!;

      if (!await service.isWebSocketProfilingAvailable(isolateId)) {
        return;
      }

      final profile = await service.getWebSocketProfile(
        isolateId,
        updatedSince: DateTime.fromMicrosecondsSinceEpoch(
          lastWebSocketDataRefreshTimePerIsolate.putIfAbsent(
            isolateId,
            // If a new isolate has spawned, request all WebSocket connections
            // from the start of the profile.
            () => 0,
          ),
        ),
      );

      final fullConnections = await Future.wait(
        profile.connections.map(
          (connection) =>
              service.getWebSocketConnection(isolateId, connection.id),
        ),
      );

      connections.addAll(fullConnections);

      // Use the profile timestamp rather than DateTime.now() so that we don't
      // miss updates between the profile snapshot and this assignment.
      lastWebSocketDataRefreshTimePerIsolate[isolateId] =
          profile.timestamp.microsecondsSinceEpoch;
    });

    return connections;
  }

  Future<void> _clearWebSocketProfile() async {
    final service = serviceConnection.serviceManager.service;
    if (service == null) return;

    await service.forEachIsolate((isolate) async {
      final isolateId = isolate.id!;

      if (!await service.isWebSocketProfilingAvailable(isolateId)) {
        return;
      }

      final future = service.clearWebSocketProfile(isolateId);

      // The call may not complete immediately if the isolate is paused.
      await timeout(future, 500);
    });
  }

  Future<List<SocketStatistic>> _refreshSockets() async {
    final service = serviceConnection.serviceManager.service;
    if (service == null) return [];
    final sockets = <SocketStatistic>[];
    await service.forEachIsolate((isolate) async {
      final socketProfile = await service.getSocketProfileWrapper(isolate.id!);
      sockets.addAll(socketProfile.sockets);
    });

    // TODO(https://github.com/flutter/devtools/issues/5057):
    // Filter lastrefreshMicros inside [service.getSocketProfile] instead.
    final lastSocketDataRefreshMicros =
        networkController.lastSocketDataRefreshMicros;
    return [
      ...sockets.where(
        (element) =>
            element.startTime > lastSocketDataRefreshMicros ||
            (element.endTime ?? 0) > lastSocketDataRefreshMicros ||
            (element.lastReadTime ?? 0) > lastSocketDataRefreshMicros ||
            (element.lastWriteTime ?? 0) > lastSocketDataRefreshMicros,
      ),
    ];
  }

  Future<void> _clearSocketProfile() async {
    final service = serviceConnection.serviceManager.service;
    if (service == null) return;
    await service.forEachIsolate((isolate) async {
      final isolateId = isolate.id!;
      final socketProfilingAvailable = await service
          .isSocketProfilingAvailableWrapper(isolateId);
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
      final socketProfilingAvailable = await service
          .isSocketProfilingAvailableWrapper(isolateId);
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
    try {
      await updateLastSocketDataRefreshTime();
      await updateLastHttpDataRefreshTime();
      await _clearSocketProfile();
      await _clearHttpProfile();
      await _clearWebSocketProfile();
    } on RPCError catch (e) {
      if (!e.isServiceDisposedError) {
        rethrow;
      }
    }
  }
}
