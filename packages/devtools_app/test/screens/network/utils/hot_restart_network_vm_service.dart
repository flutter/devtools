// Copyright 2026 The Flutter Authors
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

  /// A monotonic microsecond counter simulating the VM timeline clock.
  int _timelineMicros = 1_000_000;

  /// A map of isolate ID to the list of mock HTTP requests recorded on that
  /// isolate.
  final _httpProfiles = <String, List<HttpProfileRequest>>{};

  /// A map of isolate ID to the list of mock socket statistics recorded on that
  /// isolate.
  final _socketProfiles = <String, List<SocketStatistic>>{};

  /// A map tracking whether HTTP timeline logging is enabled (true/false) per
  /// isolate ID.
  final _httpLoggingEnabled = <String, bool>{};

  /// A map tracking whether socket profiling is enabled (true/false) per isolate
  /// ID.
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
    // Advance past pre-restart request timestamps so refresh logic treats them
    // as stale on the new isolate.
    _timelineMicros += 5_000_000;
    return nextId;
  }

  /// Appends [request] to the HTTP profile for [isolateId].
  void appendHttpRequest(String isolateId, HttpProfileRequest request) {
    _httpProfiles[isolateId] = [...?_httpProfiles[isolateId], request];
  }

  @override
  Future<Success> clearHttpProfileWrapper(String isolateId) async {
    _httpProfiles[isolateId] = [];
    return Success();
  }

  @override
  Future<Success> clearSocketProfileWrapper(String isolateId) async {
    _socketProfiles[isolateId] = [];
    return Success();
  }

  @override
  Future<void> forEachIsolate(Future<void> Function(IsolateRef) callback) =>
      callback(IsolateRef.parse({'id': _currentIsolateId, 'name': 'main'})!);

  @override
  Future<HttpTimelineLoggingState> httpEnableTimelineLoggingWrapper(
    String isolateId, [
    bool? enabled,
  ]) async {
    if (enabled != null) {
      _httpLoggingEnabled[isolateId] = enabled;
      return HttpTimelineLoggingState(enabled: enabled);
    }
    return HttpTimelineLoggingState(
      enabled: _httpLoggingEnabled[isolateId] ?? false,
    );
  }

  @override
  Future<SocketProfilingState> socketProfilingEnabledWrapper(
    String isolateId, [
    bool? enabled,
  ]) async {
    if (enabled != null) {
      _socketProfilingEnabled[isolateId] = enabled;
      return SocketProfilingState(enabled: enabled);
    }
    return SocketProfilingState(
      enabled: _socketProfilingEnabled[isolateId] ?? false,
    );
  }

  @override
  Future<HttpProfile> getHttpProfileWrapper(
    String isolateId, {
    DateTime? updatedSince,
  }) async {
    if (!(_httpLoggingEnabled[isolateId] ?? false)) {
      return HttpProfile(
        requests: [],
        timestamp: DateTime.fromMicrosecondsSinceEpoch(_timelineMicros),
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
    return HttpProfile(
      requests: requests,
      timestamp: DateTime.fromMicrosecondsSinceEpoch(_timelineMicros),
    );
  }

  @override
  Future<SocketProfile> getSocketProfileWrapper(String isolateId) async {
    if (!(_socketProfilingEnabled[isolateId] ?? false)) {
      return SocketProfile(sockets: []);
    }
    return SocketProfile(sockets: _socketProfiles[isolateId] ?? const []);
  }

  @override
  Future<Timestamp> getVMTimelineMicros() async =>
      Timestamp(timestamp: _timelineMicros);
}
