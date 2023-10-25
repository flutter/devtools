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

class VmServiceWrapper implements VmService {
  VmServiceWrapper(
    this._vmService,
    this.connectedUri, {
    this.trackFutures = false,
  }) {
    unawaited(_initSupportedProtocols());
  }

  VmServiceWrapper.fromNewVmService({
    required Stream<dynamic> /*String|List<int>*/ inStream,
    required void Function(String message) writeMessage,
    required this.connectedUri,
    this.trackFutures = false,
  }) {
    _vmService = VmService(
      inStream,
      writeMessage,
      wsUri: connectedUri.toString(),
    );
    unawaited(_initSupportedProtocols());
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

  late final VmService _vmService;

  final Uri connectedUri;

  final bool trackFutures;
  final Map<String, Future<Success>> _activeStreams = {};

  final Set<TrackedFuture<Object>> activeFutures = {};
  Completer<bool> _allFuturesCompleter = Completer<bool>()
    // Mark the future as completed by default so if we don't track any
    // futures but someone tries to wait on [allFuturesCompleted] they don't
    // hang. The first tracked future will replace this with a new completer.
    ..complete(true);

  Future<void> get allFuturesCompleted => _allFuturesCompleter.future;

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
  Future<Breakpoint> addBreakpoint(
    String isolateId,
    String scriptId,
    int line, {
    int? column,
  }) {
    return trackFuture(
      'addBreakpoint',
      _vmService.addBreakpoint(isolateId, scriptId, line, column: column),
    );
  }

  @override
  Future<Breakpoint> addBreakpointAtEntry(String isolateId, String functionId) {
    return trackFuture(
      'addBreakpointAtEntry',
      _vmService.addBreakpointAtEntry(isolateId, functionId),
    );
  }

  @override
  Future<Breakpoint> addBreakpointWithScriptUri(
    String isolateId,
    String scriptUri,
    int line, {
    int? column,
  }) {
    return trackFuture(
      'addBreakpointWithScriptUri',
      _vmService.addBreakpointWithScriptUri(
        isolateId,
        scriptUri,
        line,
        column: column,
      ),
    );
  }

  @override
  Future<Response> callMethod(
    String method, {
    String? isolateId,
    Map<String, dynamic>? args,
  }) {
    return trackFuture(
      'callMethod $method',
      _vmService.callMethod(method, isolateId: isolateId, args: args),
    );
  }

  @override
  Future<Response> callServiceExtension(
    String method, {
    String? isolateId,
    Map<String, dynamic>? args,
  }) {
    return trackFuture(
      'callServiceExtension $method',
      _vmService.callServiceExtension(
        method,
        isolateId: isolateId,
        args: args,
      ),
    );
  }

  @override
  Future<Success> clearCpuSamples(String isolateId) async {
    return trackFuture(
      'clearCpuSamples',
      _vmService.clearCpuSamples(isolateId),
    );
  }

  @override
  Future<Success> clearVMTimeline() async {
    return trackFuture('clearVMTimeline', _vmService.clearVMTimeline());
  }

  @override
  Future get onDone => _vmService.onDone;

  @override
  Future<void> dispose() => _vmService.dispose();

  @override
  Future<Response> evaluate(
    String isolateId,
    String targetId,
    String expression, {
    Map<String, String>? scope,
    bool? disableBreakpoints,
  }) {
    return trackFuture(
      'evaluate $expression',
      _vmService.evaluate(
        isolateId,
        targetId,
        expression,
        scope: scope,
        disableBreakpoints: disableBreakpoints,
      ),
    );
  }

  @override
  Future<Response> evaluateInFrame(
    String isolateId,
    int frameIndex,
    String expression, {
    Map<String, String>? scope,
    bool? disableBreakpoints,
  }) {
    return trackFuture(
      'evaluateInFrame $expression',
      _vmService.evaluateInFrame(
        isolateId,
        frameIndex,
        expression,
        scope: scope,
        disableBreakpoints: disableBreakpoints,
      ),
    );
  }

  @override
  Future<AllocationProfile> getAllocationProfile(
    String isolateId, {
    bool? reset,
    bool? gc,
  }) async {
    return trackFuture(
      'getAllocationProfile',
      _vmService.callMethod(
        // TODO(bkonyi): add _new and _old to public response.
        '_getAllocationProfile',
        isolateId: isolateId,
        args: <String, dynamic>{
          if (reset != null && reset) 'reset': reset,
          if (gc != null && gc) 'gc': gc,
        },
      ).then((r) => r as AllocationProfile),
    );
  }

  @override
  Future<CpuSamples> getCpuSamples(
    String isolateId,
    int timeOriginMicros,
    int timeExtentMicros,
  ) async {
    return trackFuture(
      'getCpuSamples',
      _vmService.callMethod(
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
      ).then((e) => e as CpuSamples),
    );
  }

  @override
  Future<FlagList> getFlagList() =>
      trackFuture('getFlagList', _vmService.getFlagList());

  @override
  Future<InstanceSet> getInstances(
    String isolateId,
    String objectId,
    int limit, {
    bool? includeSubclasses,
    bool? includeImplementers,
  }) async {
    return trackFuture(
      'getInstances',
      _vmService.getInstances(
        isolateId,
        objectId,
        limit,
        includeSubclasses: includeSubclasses,
        includeImplementers: includeImplementers,
      ),
    );
  }

  @override
  Future<InstanceRef> getInstancesAsList(
    String isolateId,
    String objectId, {
    bool? includeSubclasses,
    bool? includeImplementers,
  }) async {
    return trackFuture(
      'getInstancesAsList',
      _vmService.getInstancesAsList(
        isolateId,
        objectId,
        includeSubclasses: includeSubclasses,
        includeImplementers: includeImplementers,
      ),
    );
  }

  @override
  Future<Isolate> getIsolate(String isolateId) {
    return trackFuture('getIsolate', _vmService.getIsolate(isolateId));
  }

  @override
  Future<IsolateGroup> getIsolateGroup(String isolateGroupId) {
    return trackFuture(
      'getIsolateGroup',
      _vmService.getIsolateGroup(isolateGroupId),
    );
  }

  @override
  Future<MemoryUsage> getIsolateGroupMemoryUsage(String isolateGroupId) {
    return trackFuture(
      'getIsolateGroupMemoryUsage',
      _vmService.getIsolateGroupMemoryUsage(isolateGroupId),
    );
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
    return trackFuture(
      'getObject',
      _vmService.getObject(
        isolateId,
        objectId,
        offset: offset,
        count: count,
      ),
    );
  }

  @override
  Future<ScriptList> getScripts(String isolateId) {
    return trackFuture('getScripts', _vmService.getScripts(isolateId));
  }

  @override
  Future<ClassList> getClassList(String isolateId) {
    return trackFuture('getClassList', _vmService.getClassList(isolateId));
  }

  @override
  Future<SourceReport> getSourceReport(
    String isolateId,
    List<String> reports, {
    String? scriptId,
    int? tokenPos,
    int? endTokenPos,
    bool? forceCompile,
    bool? reportLines,
    List<String>? libraryFilters,
  }) async {
    return trackFuture(
      'getSourceReport',
      _vmService.getSourceReport(
        isolateId,
        reports,
        scriptId: scriptId,
        tokenPos: tokenPos,
        endTokenPos: endTokenPos,
        forceCompile: forceCompile,
        reportLines: reportLines,
        libraryFilters: libraryFilters,
      ),
    );
  }

  @override
  Future<Stack> getStack(String isolateId, {int? limit}) async {
    return trackFuture(
      'getStack',
      _vmService.getStack(isolateId, limit: limit),
    );
  }

  @override
  Future<VM> getVM() => trackFuture('getVM', _vmService.getVM());

  @override
  Future<Timeline> getVMTimeline({
    int? timeOriginMicros,
    int? timeExtentMicros,
  }) async {
    return trackFuture(
      'getVMTimeline',
      _vmService.getVMTimeline(
        timeOriginMicros: timeOriginMicros,
        timeExtentMicros: timeExtentMicros,
      ),
    );
  }

  @override
  Future<TimelineFlags> getVMTimelineFlags() {
    return trackFuture('getVMTimelineFlags', _vmService.getVMTimelineFlags());
  }

  @override
  Future<Timestamp> getVMTimelineMicros() async {
    return trackFuture(
      'getVMTimelineMicros',
      _vmService.getVMTimelineMicros(),
    );
  }

  @override
  Future<Version> getVersion() async {
    return trackFuture('getVersion', _vmService.getVersion());
  }

  @override
  Future<MemoryUsage> getMemoryUsage(String isolateId) =>
      trackFuture('getMemoryUsage', _vmService.getMemoryUsage(isolateId));

  @override
  Future<Response> invoke(
    String isolateId,
    String targetId,
    String selector,
    List<String> argumentIds, {
    bool? disableBreakpoints,
  }) {
    return trackFuture(
      'invoke $selector',
      _vmService.invoke(
        isolateId,
        targetId,
        selector,
        argumentIds,
        disableBreakpoints: disableBreakpoints,
      ),
    );
  }

  @override
  Future<Success> requestHeapSnapshot(String isolateId) {
    return trackFuture(
      'requestHeapSnapshot',
      _vmService.requestHeapSnapshot(isolateId),
    );
  }

  Future<HeapSnapshotGraph> getHeapSnapshotGraph(IsolateRef isolateRef) async {
    return await HeapSnapshotGraph.getSnapshot(_vmService, isolateRef);
  }

  @override
  Future<Success> kill(String isolateId) {
    return trackFuture('kill', _vmService.kill(isolateId));
  }

  @override
  Stream<Event> get onDebugEvent => _vmService.onDebugEvent;

  @override
  Stream<Event> get onProfilerEvent => _vmService.onProfilerEvent;

  @override
  Stream<Event> onEvent(String streamName) => _vmService.onEvent(streamName);

  @override
  Stream<Event> get onExtensionEvent => _vmService.onExtensionEvent;

  @override
  Stream<Event> get onGCEvent => _vmService.onGCEvent;

  @override
  Stream<Event> get onIsolateEvent => _vmService.onIsolateEvent;

  @override
  Stream<Event> get onLoggingEvent => _vmService.onLoggingEvent;

  @override
  Stream<Event> get onTimelineEvent => _vmService.onTimelineEvent;

  @override
  Stream<String> get onReceive => _vmService.onReceive;

  @override
  Stream<String> get onSend => _vmService.onSend;

  @override
  Stream<Event> get onServiceEvent => _vmService.onServiceEvent;

  @override
  Stream<Event> get onStderrEvent => _vmService.onStderrEvent;

  @override
  Stream<Event> get onStdoutEvent => _vmService.onStdoutEvent;

  @override
  Stream<Event> get onVMEvent => _vmService.onVMEvent;

  @override
  Stream<Event> get onHeapSnapshotEvent => _vmService.onHeapSnapshotEvent;

  @override
  Future<Success> pause(String isolateId) {
    return trackFuture('pause', _vmService.pause(isolateId));
  }

  @override
  Future<Success> registerService(String service, String alias) async {
    return trackFuture(
      'registerService $service',
      _vmService.registerService(service, alias),
    );
  }

  @override
  void registerServiceCallback(String service, ServiceCallback cb) {
    return _vmService.registerServiceCallback(service, cb);
  }

  @override
  Future<ReloadReport> reloadSources(
    String isolateId, {
    bool? force,
    bool? pause,
    String? rootLibUri,
    String? packagesUri,
  }) {
    return trackFuture(
      'reloadSources',
      _vmService.reloadSources(
        isolateId,
        force: force,
        pause: pause,
        rootLibUri: rootLibUri,
        packagesUri: packagesUri,
      ),
    );
  }

  @override
  Future<Success> removeBreakpoint(String isolateId, String breakpointId) {
    return trackFuture(
      'removeBreakpoint',
      _vmService.removeBreakpoint(isolateId, breakpointId),
    );
  }

  @override
  Future<Success> resume(String isolateId, {String? step, int? frameIndex}) {
    return trackFuture(
      'resume',
      _vmService.resume(isolateId, step: step, frameIndex: frameIndex),
    );
  }

  @override
  Future<Success> setIsolatePauseMode(
    String isolateId, {
    /*ExceptionPauseMode*/ String? exceptionPauseMode,
    bool? shouldPauseOnExit,
  }) {
    return trackFuture(
      'setIsolatePauseMode',
      _vmService.setIsolatePauseMode(
        isolateId,
        exceptionPauseMode: exceptionPauseMode,
        shouldPauseOnExit: shouldPauseOnExit,
      ),
    );
  }

  @override
  Future<Response> setFlag(String name, String value) {
    return trackFuture('setFlag', _vmService.setFlag(name, value));
  }

  @override
  Future<Success> setLibraryDebuggable(
    String isolateId,
    String libraryId,
    bool isDebuggable,
  ) {
    return trackFuture(
      'setLibraryDebuggable',
      _vmService.setLibraryDebuggable(isolateId, libraryId, isDebuggable),
    );
  }

  @override
  Future<Success> setName(String isolateId, String name) {
    return trackFuture('setName', _vmService.setName(isolateId, name));
  }

  @override
  Future<Success> setVMName(String name) {
    return trackFuture('setVMName', _vmService.setVMName(name));
  }

  @override
  Future<Success> setVMTimelineFlags(List<String> recordedStreams) async {
    return trackFuture(
      'setVMTimelineFlags',
      _vmService.setVMTimelineFlags(recordedStreams),
    );
  }

  @override
  Future<Success> streamCancel(String streamId) {
    _activeStreams.remove(streamId);
    return trackFuture('streamCancel', _vmService.streamCancel(streamId));
  }

  // We tweaked this method so that we do not try to listen to the same stream
  // twice. This was causing an issue with the test environment and this change
  // should not affect the run environment.
  @override
  Future<Success> streamListen(String streamId) {
    if (!_activeStreams.containsKey(streamId)) {
      final Future<Success> future =
          trackFuture('streamListen', _vmService.streamListen(streamId));
      _activeStreams[streamId] = future;
      return future;
    } else {
      return _activeStreams[streamId]!.then((value) => value);
    }
  }

  @override
  Future<InboundReferences> getInboundReferences(
    String isolateId,
    String targetId,
    int limit,
  ) async {
    return trackFuture(
      'getInboundReferences',
      _vmService.getInboundReferences(isolateId, targetId, limit),
    );
  }

  @override
  Future<RetainingPath> getRetainingPath(
    String isolateId,
    String targetId,
    int limit,
  ) =>
      trackFuture(
        'getRetainingPath',
        _vmService.getRetainingPath(isolateId, targetId, limit),
      );

  @override
  Future<CpuSamples> getAllocationTraces(
    String isolateId, {
    int? timeOriginMicros,
    int? timeExtentMicros,
    String? classId,
  }) {
    return trackFuture(
      'getAllocationTraces',
      _vmService.getAllocationTraces(
        isolateId,
        timeOriginMicros: timeOriginMicros,
        timeExtentMicros: timeExtentMicros,
        classId: classId,
      ),
    );
  }

  @override
  Future<Success> setTraceClassAllocation(
    String isolateId,
    String classId,
    bool enable,
  ) async {
    return trackFuture(
      'setTraceClassAllocation',
      _vmService.setTraceClassAllocation(isolateId, classId, enable),
    );
  }

  @override
  Future<ProcessMemoryUsage> getProcessMemoryUsage() {
    return trackFuture(
      'getProcessMemoryUsage',
      _vmService.getProcessMemoryUsage(),
    );
  }

  @override
  Future<Breakpoint> setBreakpointState(
    String isolateId,
    String breakpointId,
    bool enable,
  ) {
    return trackFuture(
      'setBreakpointState',
      _vmService.setBreakpointState(
        isolateId,
        breakpointId,
        enable,
      ),
    );
  }

  @override
  Future<ProtocolList> getSupportedProtocols() async {
    return trackFuture(
      'getSupportedProtocols',
      _vmService.getSupportedProtocols(),
    );
  }

  @override
  Future<PortList> getPorts(String isolateId) async {
    return trackFuture(
      'getPorts',
      _vmService.getPorts(isolateId),
    );
  }

  @override
  Future<UriList> lookupPackageUris(String isolateId, List<String> uris) async {
    return trackFuture(
      'lookupPackageUris',
      _vmService.lookupPackageUris(isolateId, uris),
    );
  }

  @override
  Future<UriList> lookupResolvedPackageUris(
    String isolateId,
    List<String> uris, {
    bool? local,
  }) async {
    return trackFuture(
      'lookupResolvedPackageUris',
      _vmService.lookupResolvedPackageUris(isolateId, uris, local: local),
    );
  }

  // Mark: Overrides for [DdsExtension]. It would help with logical grouping to
  // make these extension methods, but that makes testing more difficult due to
  // mocking limitations for extension methods.
  Stream<Event> get onExtensionEventWithHistory {
    return _maybeReturnStreamWithHistory(
      _vmService.onExtensionEventWithHistory,
      fallbackStream: onExtensionEvent,
    );
  }

  Stream<Event> get onLoggingEventWithHistory {
    return _maybeReturnStreamWithHistory(
      _vmService.onLoggingEventWithHistory,
      fallbackStream: onLoggingEvent,
    );
  }

  Stream<Event> get onStderrEventWithHistory {
    return _maybeReturnStreamWithHistory(
      _vmService.onStderrEventWithHistory,
      fallbackStream: onStderrEvent,
    );
  }

  Stream<Event> get onStdoutEventWithHistory {
    return _maybeReturnStreamWithHistory(
      _vmService.onStdoutEventWithHistory,
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
  // Mark: end overrides for the [DdsExtension].

  // Mark: Overrides for [DartIOExtension]. It would help with logical grouping
  // to make these extension methods, but that makes testing more difficult due
  // to mocking limitations for extension methods.
  Future<Version> getDartIOVersion(String isolateId) =>
      trackFuture('_getDartIOVersion', _vmService.getDartIOVersion(isolateId));

  Future<SocketProfilingState> socketProfilingEnabled(
    String isolateId, [
    bool? enabled,
  ]) async {
    assert(await isSocketProfilingAvailable(isolateId));
    return trackFuture(
      'socketProfilingEnabled',
      _vmService.socketProfilingEnabled(isolateId, enabled),
    );
  }

  Future<Success> clearSocketProfile(String isolateId) async {
    assert(await isSocketProfilingAvailable(isolateId));
    return trackFuture(
      'clearSocketProfile',
      _vmService.clearSocketProfile(isolateId),
    );
  }

  Future<SocketProfile> getSocketProfile(String isolateId) async {
    assert(await isSocketProfilingAvailable(isolateId));
    return trackFuture(
      'getSocketProfile',
      _vmService.getSocketProfile(isolateId),
    );
  }

  Future<HttpTimelineLoggingState> httpEnableTimelineLogging(
    String isolateId, [
    bool? enabled,
  ]) async {
    assert(await isHttpTimelineLoggingAvailable(isolateId));
    return trackFuture(
      'httpEnableTimelineLogging',
      _vmService.httpEnableTimelineLogging(isolateId, enabled),
    );
  }

  /// The `getHttpProfile` RPC is used to retrieve HTTP profiling information
  /// for requests made via `dart:io`'s `HttpClient`.
  ///
  /// The returned [HttpProfile] will only include requests issued after
  /// [httpTimelineLogging] has been enabled or after the last
  /// [clearHttpProfile] invocation.
  Future<HttpProfile> getHttpProfile(
    String isolateId, {
    int? updatedSince,
  }) async {
    assert(await isHttpProfilingAvailable(isolateId));
    return trackFuture(
      'getHttpProfile',
      _vmService.getHttpProfile(
        isolateId,
        updatedSince: updatedSince,
      ),
    );
  }

  Future<HttpProfileRequest> getHttpProfileRequest(
    String isolateId,
    String id,
  ) async {
    assert(await isHttpProfilingAvailable(isolateId));
    return trackFuture(
      'getHttpProfileRequest',
      _vmService.getHttpProfileRequest(isolateId, id),
    );
  }

  /// The `clearHttpProfile` RPC is used to clear previously recorded HTTP
  /// requests from the HTTP profiler state. Requests still in-flight after
  /// clearing the profiler state will be ignored by the profiler.
  Future<Success> clearHttpProfile(String isolateId) async {
    assert(await isHttpProfilingAvailable(isolateId));
    return trackFuture(
      'clearHttpProfile',
      _vmService.clearHttpProfile(isolateId),
    );
  }

  // TODO(kenz): move this method to
  // https://github.com/dart-lang/sdk/blob/master/pkg/vm_service/lib/src/dart_io_extensions.dart
  Future<bool> isSocketProfilingAvailable(String isolateId) async {
    final Isolate isolate = await getIsolate(isolateId);
    return (isolate.extensionRPCs ?? [])
        .contains('ext.dart.io.getSocketProfile');
  }

  // TODO(kenz): move this method to
  // https://github.com/dart-lang/sdk/blob/master/pkg/vm_service/lib/src/dart_io_extensions.dart
  Future<bool> isHttpTimelineLoggingAvailable(String isolateId) async {
    final Isolate isolate = await getIsolate(isolateId);
    final rpcs = isolate.extensionRPCs ?? [];
    return rpcs.contains('ext.dart.io.httpEnableTimelineLogging');
  }

  // TODO(bkonyi): move this method to
  // https://github.com/dart-lang/sdk/blob/master/pkg/vm_service/lib/src/dart_io_extensions.dart
  Future<bool> isHttpProfilingAvailable(String isolateId) async {
    final Isolate isolate = await getIsolate(isolateId);
    return (isolate.extensionRPCs ?? []).contains('ext.dart.io.getHttpProfile');
  }
  // Mark: end overrides for the [DartIOExtension].

  /// Testing only method to indicate that we don't really need to await all
  /// currently pending futures.
  ///
  /// If you use this method be sure to indicate why you believe all pending
  /// futures are safe to ignore. Currently the theory is this method should be
  /// used after a hot restart to avoid bugs where we have zombie futures lying
  /// around causing tests to flake.
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
      _log.fine('[$logId]-trackFuture($name,...): Started');
      final result = await future;
      _log.fine('[$logId]-trackFuture($name,...): Succeeded');
      return result;
    } catch (error) {
      _log.severe(
        '[$logId]-trackFuture($name,...): Failed',
        error,
      );
      rethrow;
    }
  }

  @visibleForTesting
  Future<T> trackFuture<T>(String name, Future<T> future) {
    final localFuture = _maybeLogWrappedFuture<T>(name, future);

    if (!trackFutures) {
      return localFuture;
    }
    vmServiceCallCount++;
    vmServiceCalls.add(name);

    final trackedFuture = TrackedFuture<Object>(name);
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
    final result = await trackFuture(
      method,
      callMethod(
        '_$method',
        isolateId: isolateId,
        args: args,
      ),
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

    final response = await trackFuture(
      'dap.$command',
      _vmService.sendDapRequest(
        jsonEncode(
          dap.Request(
            command: command,
            seq: _dapSeq++,
            arguments: args,
          ),
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

  /// Prevent DevTools from blocking Dart SDK rolls if changes in
  /// package:vm_service are unimplemented in DevTools.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class TrackedFuture<T> {
  TrackedFuture(this.name);

  final String name;
}
