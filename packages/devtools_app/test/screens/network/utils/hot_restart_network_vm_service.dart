// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:vm_service/vm_service.dart';

/// A fake VM service that models hot-restart isolate lifecycle for Network View
/// tests.
///
/// After a hot restart, the VM spawns a new main isolate whose HTTP timeline
/// logging and socket profiling are disabled until explicitly re-enabled.
/// [getHttpProfileWrapper] and [getSocketProfileWrapper] return empty data when
/// profiling is disabled for an isolate, matching real VM behavior.
class HotRestartNetworkVmService extends FakeVmServiceWrapper {
  HotRestartNetworkVmService()
    : super(
        _testVmFlagManager,
        null,
        null,
        SocketProfile(sockets: []),
        HttpProfile(
          requests: [],
          timestamp: DateTime.fromMicrosecondsSinceEpoch(0),
        ),
        null,
        null,
        null,
        null,
        null,
        null,
        null,
      ) {
    isHttpProfilingAvailableResult = true;
    _httpLoggingEnabled[_currentIsolateId] = false;
    _socketProfilingEnabled[_currentIsolateId] = false;
  }

  static final _testVmFlagManager = VmFlagManager();

  String _currentIsolateId = 'isolates/1';
  int _timelineMicros = 1000000;

  final _httpProfiles = <String, List<HttpProfileRequest>>{};
  final _socketProfiles = <String, List<SocketStatistic>>{};
  final _httpLoggingEnabled = <String, bool>{};
  final _socketProfilingEnabled = <String, bool>{};

  /// The isolate ID currently returned by [forEachIsolate].
  String get currentIsolateId => _currentIsolateId;

  /// Sets the HTTP profile data that will be returned for [isolateId] when HTTP
  /// timeline logging is enabled for that isolate.
  void setHttpProfile(String isolateId, List<HttpProfileRequest> requests) {
    _httpProfiles[isolateId] = requests;
  }

  /// Sets the socket profile data that will be returned for [isolateId] when
  /// socket profiling is enabled for that isolate.
  void setSocketProfile(String isolateId, List<SocketStatistic> sockets) {
    _socketProfiles[isolateId] = sockets;
  }

  /// Whether HTTP timeline logging is enabled for [isolateId].
  bool isHttpLoggingEnabled(String isolateId) =>
      _httpLoggingEnabled[isolateId] ?? false;

  /// Whether socket profiling is enabled for [isolateId].
  bool isSocketProfilingEnabled(String isolateId) =>
      _socketProfilingEnabled[isolateId] ?? false;

  /// Simulates a hot restart by replacing the current isolate with a new one
  /// that has HTTP logging and socket profiling disabled.
  ///
  /// Returns the ID of the new isolate.
  String simulateHotRestart({String? newIsolateId}) {
    final nextId = newIsolateId ?? '${_currentIsolateId}_restarted';
    _currentIsolateId = nextId;
    _httpLoggingEnabled[nextId] = false;
    _socketProfilingEnabled[nextId] = false;
    _timelineMicros += 5000000;
    return nextId;
  }

  /// Appends [request] to the HTTP profile for [isolateId].
  void appendHttpRequest(String isolateId, HttpProfileRequest request) {
    _httpProfiles[isolateId] = [
      ...(_httpProfiles[isolateId] ?? const []),
      request,
    ];
  }

  @override
  Future<Success> clearHttpProfileWrapper(String isolateId) {
    _httpProfiles[isolateId] = [];
    return Future.value(Success());
  }

  @override
  Future<Success> clearSocketProfileWrapper(String isolateId) {
    _socketProfiles[isolateId] = [];
    return Future.value(Success());
  }

  @override
  Future<void> forEachIsolate(Future<void> Function(IsolateRef) callback) =>
      callback(IsolateRef.parse({'id': _currentIsolateId, 'name': 'main'})!);

  @override
  Future<HttpTimelineLoggingState> httpEnableTimelineLoggingWrapper(
    String isolateId, [
    bool? enabled,
  ]) {
    if (enabled != null) {
      _httpLoggingEnabled[isolateId] = enabled;
      return Future.value(HttpTimelineLoggingState(enabled: enabled));
    }
    return Future.value(
      HttpTimelineLoggingState(
        enabled: _httpLoggingEnabled[isolateId] ?? false,
      ),
    );
  }

  @override
  Future<SocketProfilingState> socketProfilingEnabledWrapper(
    String isolateId, [
    bool? enabled,
  ]) {
    if (enabled != null) {
      _socketProfilingEnabled[isolateId] = enabled;
      return Future.value(SocketProfilingState(enabled: enabled));
    }
    return Future.value(
      SocketProfilingState(
        enabled: _socketProfilingEnabled[isolateId] ?? false,
      ),
    );
  }

  @override
  Future<HttpProfile> getHttpProfileWrapper(
    String isolateId, {
    DateTime? updatedSince,
  }) {
    if (!(_httpLoggingEnabled[isolateId] ?? false)) {
      return Future.value(
        HttpProfile(
          requests: [],
          timestamp: DateTime.fromMicrosecondsSinceEpoch(_timelineMicros),
        ),
      );
    }

    var requests = List<HttpProfileRequest>.from(
      _httpProfiles[isolateId] ?? const [],
    );
    if (updatedSince != null) {
      final sinceMicros = updatedSince.microsecondsSinceEpoch;
      requests = requests
          .where(
            (request) =>
                request.startTime.microsecondsSinceEpoch >= sinceMicros,
          )
          .toList();
    }
    return Future.value(
      HttpProfile(
        requests: requests,
        timestamp: DateTime.fromMicrosecondsSinceEpoch(_timelineMicros),
      ),
    );
  }

  @override
  Future<SocketProfile> getSocketProfileWrapper(String isolateId) {
    if (!(_socketProfilingEnabled[isolateId] ?? false)) {
      return Future.value(SocketProfile(sockets: []));
    }
    return Future.value(
      SocketProfile(sockets: _socketProfiles[isolateId] ?? const []),
    );
  }

  @override
  Future<Timestamp> getVMTimelineMicros() =>
      Future.value(Timestamp(timestamp: _timelineMicros));
}
