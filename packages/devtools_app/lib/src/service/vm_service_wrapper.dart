// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Code needs to match API from VmService.
// ignore_for_file: avoid-dynamic
library vm_service_wrapper;

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:dap/dap.dart' as dap;
import 'package:dds_service_extensions/dap.dart';
import 'package:dds_service_extensions/dds_service_extensions.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vm_service/vm_service.dart';

import '../screens/vm_developer/vm_service_private_extensions.dart';
import '../shared/feature_flags.dart';
import '../shared/globals.dart';
import '../shared/primitives/utils.dart';
import 'json_to_service_cache.dart';

final _log = Logger('vm_service_wrapper');

class VmServiceWrapper extends VmService {
  VmServiceWrapper(
    super.inStream,
    super.writeMessage, {
    super.log,
    super.disposeHandler,
    super.streamClosed,
    super.wsUri,
    bool trackFutures = false,
  }) : _trackFutures = trackFutures {
    unawaited(_initSupportedProtocols());
  }

  static VmServiceWrapper defaultFactory({
    required Stream<dynamic> /*String|List<int>*/ inStream,
    required void Function(String message) writeMessage,
    Log? log,
    DisposeHandler? disposeHandler,
    Future? streamClosed,
    String? wsUri,
    bool trackFutures = false,
  }) {
    return VmServiceWrapper(
      inStream,
      writeMessage,
      log: log,
      disposeHandler: disposeHandler,
      streamClosed: streamClosed,
      wsUri: wsUri,
      trackFutures: trackFutures,
    );
  }

  // TODO(https://github.com/dart-lang/sdk/issues/49072): in the long term, do
  // not support diverging DevTools functionality based on whether the DDS
  // protocol is supported. Conditional logic around [_ddsSupported] was added
  // in https://github.com/flutter/devtools/pull/4119 as a workaround for
  // profiling the analysis server.
  Future<void> _initSupportedProtocols() async {
    final supportedProtocols = await getSupportedProtocols();
    final ddsProtocol = supportedProtocols.protocols?.firstWhereOrNull(
      (Protocol p) => p.protocolName?.caseInsensitiveEquals('DDS') ?? false,
    );
    _ddsSupported = ddsProtocol != null;
    _supportedProtocolsInitialized.complete();
  }

  final _supportedProtocolsInitialized = Completer<void>();

  bool _ddsSupported = false;

  final bool _trackFutures;

  final Map<String, Future<Success>> _activeStreams = {};

  final Set<TrackedFuture<Object>> activeFutures = {};

  Future<void> get allFuturesCompleted => _allFuturesCompleter.future;

  Completer<bool> _allFuturesCompleter = Completer<bool>()
    // Mark the future as completed by default so if we don't track any
    // futures but someone tries to wait on [allFuturesCompleted] they don't
    // hang. The first tracked future will replace this with a new completer.
    ..complete(true);

  // A local cache of "fake" service objects. Used to convert JSON objects to
  // VM service response formats to be used with APIs that require them.
  final fakeServiceCache = JsonToServiceCache();

  /// A counter for unique ids to add to each of a future's messages.
  static int _logIdCounter = 0;

  /// A sequence number incremented and attached to each DAP request.
  static int _dapSeq = 0;

  /// Executes `callback` for each isolate, and waiting for all callbacks to
  /// finish before completing.
  Future<void> forEachIsolate(
    Future<void> Function(IsolateRef) callback,
  ) async {
    await forEachIsolateHelper(this, callback);
  }

  @override
  Future<AllocationProfile> getAllocationProfile(
    String isolateId, {
    bool? reset,
    bool? gc,
  }) async {
    return callMethod(
      // TODO(bkonyi): add _new and _old to public response.
      '_getAllocationProfile',
      isolateId: isolateId,
      args: <String, dynamic>{
        if (reset != null && reset) 'reset': reset,
        if (gc != null && gc) 'gc': gc,
      },
    ).then((r) => r as AllocationProfile);
  }

  @override
  Future<CpuSamples> getCpuSamples(
    String isolateId,
    int timeOriginMicros,
    int timeExtentMicros,
  ) async {
    return callMethod(
      'getCpuSamples',
      isolateId: isolateId,
      args: {
        'timeOriginMicros': timeOriginMicros,
        'timeExtentMicros': timeExtentMicros,
        // Requests the code profile in addition to the function profile when
        // running with VM developer mode enabled. This data isn't accessible
        // in non-VM developer mode, so not requesting the code profile will
        // save on space and network usage.
        '_code': preferences.vmDeveloperModeEnabled.value,
      },
    ).then((e) => e as CpuSamples);
  }

  @override
  Future<Obj> getObject(
    String isolateId,
    String objectId, {
    int? offset,
    int? count,
  }) {
    final cachedObj = fakeServiceCache.getObject(
      objectId: objectId,
      offset: offset,
      count: count,
    );
    if (cachedObj != null) {
      return Future.value(cachedObj);
    }
    return getObject(
      isolateId,
      objectId,
      offset: offset,
      count: count,
    );
  }

  Future<HeapSnapshotGraph> getHeapSnapshotGraph(IsolateRef isolateRef) async {
    return await HeapSnapshotGraph.getSnapshot(this, isolateRef);
  }

  @override
  Future<Success> streamCancel(String streamId) {
    _activeStreams.remove(streamId);
    return super.streamCancel(streamId);
  }

  // We tweaked this method so that we do not try to listen to the same stream
  // twice. This was causing an issue with the test environment and this change
  // should not affect the run environment.
  @override
  Future<Success> streamListen(String streamId) {
    if (!_activeStreams.containsKey(streamId)) {
      return _activeStreams[streamId] = super.streamListen(streamId);
    } else {
      return _activeStreams[streamId]!.then((value) => value);
    }
  }

  // Mark: Overrides for [DdsExtension]. It would help with logical grouping to
  // make these extension methods, but that makes testing more difficult due to
  // mocking limitations for extension methods.
  Stream<Event> get onExtensionEventWithHistorySafe {
    return _maybeReturnStreamWithHistory(
      onExtensionEventWithHistory,
      fallbackStream: onExtensionEvent,
    );
  }

  Stream<Event> get onLoggingEventWithHistorySafe {
    return _maybeReturnStreamWithHistory(
      onLoggingEventWithHistory,
      fallbackStream: onLoggingEvent,
    );
  }

  Stream<Event> get onStderrEventWithHistorySafe {
    return _maybeReturnStreamWithHistory(
      onStderrEventWithHistory,
      fallbackStream: onStderrEvent,
    );
  }

  Stream<Event> get onStdoutEventWithHistorySafe {
    return _maybeReturnStreamWithHistory(
      onStdoutEventWithHistory,
      fallbackStream: onStdoutEvent,
    );
  }

  Stream<Event> _maybeReturnStreamWithHistory(
    Stream<Event> ddsStream, {
    required Stream<Event> fallbackStream,
  }) {
    assert(_supportedProtocolsInitialized.isCompleted);
    if (_ddsSupported) {
      return ddsStream;
    }
    return fallbackStream;
  }

  // Begin Dart IO extension method wrappers. We wrap these methods so that we
  // can override them in tests.

  Future<bool> isSocketProfilingAvailableWrapper(String isolateId) async {
    return isSocketProfilingAvailable(isolateId);
  }

  Future<SocketProfilingState> socketProfilingEnabledWrapper(
    String isolateId, [
    bool? enabled,
  ]) async {
    return socketProfilingEnabled(isolateId, enabled);
  }

  Future<Success> clearSocketProfileWrapper(String isolateId) async {
    return clearSocketProfile(isolateId);
  }

  Future<SocketProfile> getSocketProfileWrapper(String isolateId) async {
    return getSocketProfile(isolateId);
  }

  Future<HttpProfileRequest> getHttpProfileRequestWrapper(
    String isolateId,
    String id,
  ) async {
    return getHttpProfileRequest(isolateId, id);
  }

  Future<HttpProfile> getHttpProfileWrapper(
    String isolateId, {
    int? updatedSince,
  }) async {
    return getHttpProfile(isolateId, updatedSince: updatedSince);
  }

  Future<Success> clearHttpProfileWrapper(String isolateId) async {
    return clearHttpProfile(isolateId);
  }

  Future<bool> isHttpTimelineLoggingAvailableWrapper(String isolateId) async {
    return isHttpTimelineLoggingAvailable(isolateId);
  }

  Future<HttpTimelineLoggingState> httpEnableTimelineLoggingWrapper(
    String isolateId, [
    bool? enabled,
  ]) async {
    return httpEnableTimelineLogging(isolateId, enabled);
  }

  // End Dart IO extension method wrappers.

  /// Testing only method to indicate that we don't really need to await all
  /// currently pending futures.
  ///
  /// If you use this method be sure to indicate why you believe all pending
  /// futures are safe to ignore. Currently the theory is this method should be
  /// used after a hot restart to avoid bugs where we have zombie futures lying
  /// around causing tests to flake.
  @visibleForTesting
  void doNotWaitForPendingFuturesBeforeExit() {
    _allFuturesCompleter = Completer<bool>();
    _allFuturesCompleter.complete(true);
    activeFutures.clear();
  }

  @visibleForTesting
  int vmServiceCallCount = 0;

  @visibleForTesting
  final vmServiceCalls = <String>[];

  @visibleForTesting
  void clearVmServiceCalls() {
    vmServiceCalls.clear();
    vmServiceCallCount = 0;
  }

  /// If logging is enabled, wraps a future with logs at its start and finish.
  ///
  /// All logs from this run will have matching unique ids, so that they can
  /// be associated together in the logs.
  Future<T> _maybeLogWrappedFuture<T>(
    String name,
    Future<T> future,
  ) async {
    // If the logger is not accepting FINE logs, then we won't be logging any
    // messages. So just return the [future] as-is.
    if (!_log.isLoggable(Level.FINE)) return future;

    final logId = ++_logIdCounter;
    try {
      _log.fine('[$logId]-wrapFuture($name,...): Started');
      final result = await future;
      _log.fine('[$logId]-wrapFuture($name,...): Succeeded');
      return result;
    } catch (error) {
      _log.severe(
        '[$logId]-wrapFuture($name,...): Failed',
        error,
      );
      rethrow;
    }
  }

  @override
  Future<T> wrapFuture<T>(String name, Future<T> future) {
    final localFuture = _maybeLogWrappedFuture<T>(name, future);

    if (!_trackFutures) {
      return localFuture;
    }
    vmServiceCallCount++;
    vmServiceCalls.add(name);

    final trackedFuture = TrackedFuture(name, localFuture as Future<Object>);
    if (_allFuturesCompleter.isCompleted) {
      _allFuturesCompleter = Completer<bool>();
    }
    activeFutures.add(trackedFuture);

    void futureComplete() {
      activeFutures.remove(trackedFuture);
      if (activeFutures.isEmpty && !_allFuturesCompleter.isCompleted) {
        _allFuturesCompleter.complete(true);
      }
    }

    localFuture.then(
      (value) => futureComplete(),
      onError: (error) => futureComplete(),
    );
    return localFuture;
  }

  /// Adds support for private VM RPCs that can only be used when VM developer
  /// mode is enabled. Not for use outside of VM developer pages.
  /// Allows callers to invoke extension methods for private RPCs. This should
  /// only be set by [PreferencesController.toggleVmDeveloperMode] or tests.
  static bool enablePrivateRpcs = false;

  Future<T?> _privateRpcInvoke<T>(
    String method, {
    required T? Function(Map<String, dynamic>?) parser,
    String? isolateId,
    Map<String, dynamic>? args,
  }) async {
    if (!enablePrivateRpcs) {
      throw StateError('Attempted to invoke private RPC');
    }
    final result = await callMethod(
      '_$method',
      isolateId: isolateId,
      args: args,
    );
    return parser(result.json);
  }

  /// Forces the VM to perform a full garbage collection.
  Future<Success?> collectAllGarbage() => _privateRpcInvoke(
        'collectAllGarbage',
        parser: Success.parse,
      );

  Future<InstanceRef?> getReachableSize(String isolateId, String targetId) =>
      _privateRpcInvoke(
        'getReachableSize',
        isolateId: isolateId,
        args: {
          'targetId': targetId,
        },
        parser: InstanceRef.parse,
      );

  Future<InstanceRef?> getRetainedSize(String isolateId, String targetId) =>
      _privateRpcInvoke(
        'getRetainedSize',
        isolateId: isolateId,
        args: {
          'targetId': targetId,
        },
        parser: InstanceRef.parse,
      );

  Future<ObjectStore?> getObjectStore(String isolateId) => _privateRpcInvoke(
        'getObjectStore',
        isolateId: isolateId,
        parser: ObjectStore.parse,
      );

  Future<dap.VariablesResponseBody?> dapVariablesRequest(
    dap.VariablesArguments args,
  ) async {
    final response = await _sendDapRequest('variables', args: args);
    if (response == null) return null;

    return dap.VariablesResponseBody.fromJson(
      response as Map<String, Object?>,
    );
  }

  Future<dap.ScopesResponseBody?> dapScopesRequest(
    dap.ScopesArguments args,
  ) async {
    final response = await _sendDapRequest('scopes', args: args);
    if (response == null) return null;

    return dap.ScopesResponseBody.fromJson(
      response as Map<String, Object?>,
    );
  }

  Future<dap.StackTraceResponseBody?> dapStackTraceRequest(
    dap.StackTraceArguments args,
  ) async {
    final response = await _sendDapRequest('stackTrace', args: args);
    if (response == null) return null;

    return dap.StackTraceResponseBody.fromJson(
      response as Map<String, Object?>,
    );
  }

  Future<Object?> _sendDapRequest(
    String command, {
    required Object? args,
  }) async {
    if (!FeatureFlags.dapDebugging) return null;

    // Warn the user if there is no DDS connection.
    if (!_ddsSupported) {
      _log.warning('A DDS connection is required to debug via DAP.');
      return null;
    }

    final response = await sendDapRequest(
      jsonEncode(
        dap.Request(
          command: command,
          seq: _dapSeq++,
          arguments: args,
        ),
      ),
    );

    // Log any errors from DAP if the request failed:
    if (!response.dapResponse.success) {
      _log.warning(
        'Error for dap.$command: ${response.dapResponse.message ?? 'Unknown.'}',
      );
      return null;
    }

    return response.dapResponse.body;
  }
}

class TrackedFuture<T> {
  TrackedFuture(this.name, this.future);

  final String name;
  final Future<T> future;
}
