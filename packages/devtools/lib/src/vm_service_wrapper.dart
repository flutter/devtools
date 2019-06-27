// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

class VmServiceWrapper implements VmService {
  VmServiceWrapper(
    this._vmService, {
    this.trackFutures = false,
  });

  VmServiceWrapper.fromNewVmService(
    Stream<dynamic> /*String|List<int>*/ inStream,
    void writeMessage(String message), {
    Log log,
    DisposeHandler disposeHandler,
    this.trackFutures = false,
  }) {
    _vmService = VmService(inStream, writeMessage,
        log: log, disposeHandler: disposeHandler);
  }

  VmService _vmService;
  Version _protocolVersion;
  final bool trackFutures;
  final Map<String, Future<Success>> _activeStreams = {};

  // TODO(dantup): Remove this ignore, change to `{}` and bump SDK requirements
  // in pubspec.yaml (devtools + devtools_server) once Flutter stable includes
  // Dart SDK >= v2.2.
  // ignore: prefer_collection_literals
  final Set<TrackedFuture<Object>> activeFutures = Set();
  Completer<bool> _allFuturesCompleter = Completer<bool>()
    // Mark the future as completed by default so if we don't track any
    // futures but someone tries to wait on [allFuturesCompleted] they don't
    // hang. The first tracked future will replace this with a new completer.
    ..complete(true);

  Future<void> get allFuturesCompleted => _allFuturesCompleter.future;

  @override
  Future<Breakpoint> addBreakpoint(
    String isolateId,
    String scriptId,
    int line, {
    int column,
  }) {
    return _trackFuture('addBreakpoint',
        _vmService.addBreakpoint(isolateId, scriptId, line, column: column));
  }

  @override
  Future<Breakpoint> addBreakpointAtEntry(String isolateId, String functionId) {
    return _trackFuture('addBreakpointAtEntry',
        _vmService.addBreakpointAtEntry(isolateId, functionId));
  }

  @override
  Future<Breakpoint> addBreakpointWithScriptUri(
    String isolateId,
    String scriptUri,
    int line, {
    int column,
  }) {
    return _trackFuture(
        'addBreakpointWithScriptUri',
        _vmService.addBreakpointWithScriptUri(
          isolateId,
          scriptUri,
          line,
          column: column,
        ));
  }

  @override
  Future<Response> callMethod(String method, {String isolateId, Map args}) {
    return _trackFuture('callMethod $method',
        _vmService.callMethod(method, isolateId: isolateId, args: args));
  }

  @override
  Future<Response> callServiceExtension(
    String method, {
    String isolateId,
    Map args,
  }) {
    return _trackFuture(
        'callServiceExtension $method',
        _vmService.callServiceExtension(
          method,
          isolateId: isolateId,
          args: args,
        ));
  }

  @override
  Future<Success> clearCpuProfile(String isolateId) {
    return _trackFuture(
        'clearCpuProfile', _vmService.clearCpuProfile(isolateId));
  }

  @override
  Future<Success> clearVMTimeline() async {
    if (await isProtocolVersionLessThan(major: 3, minor: 19)) {
      final response =
          await _trackFuture('clearVMTimeline', callMethod('_clearVMTimeline'));
      return response as Success;
    }
    return _trackFuture('clearVMTimeline', _vmService.clearVMTimeline());
  }

  @override
  Future<Success> collectAllGarbage(String isolateId) {
    return _trackFuture(
        'collectAllGarbage', _vmService.collectAllGarbage(isolateId));
  }

  @override
  void dispose() => _vmService.dispose();

  @override
  Future evaluate(
    String isolateId,
    String targetId,
    String expression, {
    Map<String, String> scope,
    bool disableBreakpoints,
  }) {
    return _trackFuture(
        'evaluate $expression',
        _vmService.evaluate(
          isolateId,
          targetId,
          expression,
          scope: scope,
          disableBreakpoints: disableBreakpoints,
        ));
  }

  @override
  Future evaluateInFrame(
    String isolateId,
    int frameIndex,
    String expression, {
    Map<String, String> scope,
    bool disableBreakpoints,
  }) {
    return _trackFuture(
        'evaluateInFrame $expression',
        _vmService.evaluateInFrame(
          isolateId,
          frameIndex,
          expression,
          scope: scope,
          disableBreakpoints: disableBreakpoints,
        ));
  }

  @override
  Future<AllocationProfile> getAllocationProfile(
    String isolateId, {
    bool reset,
    bool gc,
  }) async {
    if (await isProtocolVersionLessThan(major: 3, minor: 18)) {
      final Map<String, dynamic> args = {};
      if (gc != null && gc) {
        args['gc'] = 'full';
      }
      if (reset != null && reset) {
        args['reset'] = reset;
      }
      final response = await _trackFuture(
        'getAllocationProfile',
        callMethod('_getAllocationProfile', isolateId: isolateId, args: args),
      );
      return AllocationProfile.parse(response.json);
    }
    return _trackFuture(
      'getAllocationProfile',
      _vmService.getAllocationProfile(isolateId, reset: reset, gc: gc),
    );
  }

  @override
  Future<CpuProfile> getCpuProfile(String isolateId, String tags) {
    return _trackFuture(
        'getCpuProfile', _vmService.getCpuProfile(isolateId, tags));
  }

  // TODO(kenzie): keep track of all private methods we are currently using to
  // share with the VM team and request that they be made public.
  Future<Response> getCpuProfileTimeline(
      String isolateId, int origin, int extent) async {
    return _trackFuture(
        'getCpuProfileTimeline',
        callMethod(
          '_getCpuProfileTimeline',
          isolateId: isolateId,
          args: {
            'tags': 'None',
            'timeOriginMicros': origin,
            'timeExtentMicros': extent,
          },
        ));
  }

  @override
  Future<FlagList> getFlagList() =>
      _trackFuture('getFlagList', _vmService.getFlagList());

  @override
  Future<InstanceSet> getInstances(
    String isolateId,
    String objectId,
    int limit, {
    String classId,
  }) async {
    if (await isProtocolVersionLessThan(major: 3, minor: 20)) {
      final response = await _trackFuture(
        'getInstances',
        callMethod('_getInstances', args: {
          'isolateId': isolateId,
          'classId': classId,
          'limit': limit,
        }),
      );
      return InstanceSet.parse(response.json);
    }
    return _trackFuture(
      'getInstances',
      _vmService.getInstances(isolateId, objectId, limit),
    );
  }

  @override
  Future getIsolate(String isolateId) {
    return _trackFuture('getIsolate', _vmService.getIsolate(isolateId));
  }

  @override
  Future<Object> getObject(
    String isolateId,
    String objectId, {
    int offset,
    int count,
  }) {
    return _trackFuture('getObject', _vmService.getObject(isolateId, objectId));
  }

  @override
  Future<ScriptList> getScripts(String isolateId) {
    return _trackFuture('getScripts', _vmService.getScripts(isolateId));
  }

  @override
  Future<SourceReport> getSourceReport(
    String isolateId,
    List<String> reports, {
    String scriptId,
    int tokenPos,
    int endTokenPos,
    bool forceCompile,
  }) {
    return _trackFuture(
        'getSourceReport',
        _vmService.getSourceReport(
          isolateId,
          reports,
          scriptId: scriptId,
          tokenPos: tokenPos,
          endTokenPos: endTokenPos,
          forceCompile: forceCompile,
        ));
  }

  @override
  Future<Stack> getStack(String isolateId) {
    return _trackFuture('getStack', _vmService.getStack(isolateId));
  }

  @override
  Future<VM> getVM() => _trackFuture('getVM', _vmService.getVM());

  @override
  Future<Timeline> getVMTimeline({
    int timeOriginMicros,
    int timeExtentMicros,
  }) async {
    if (await isProtocolVersionLessThan(major: 3, minor: 19)) {
      final Response response =
          await _trackFuture('getVMTimeline', callMethod('_getVMTimeline'));
      return Timeline.parse(response.json);
    }
    return _trackFuture(
      'getVMTimeline',
      _vmService.getVMTimeline(
        timeOriginMicros: timeOriginMicros,
        timeExtentMicros: timeExtentMicros,
      ),
    );
  }

  @override
  Future<TimelineFlags> getVMTimelineFlags() {
    return _trackFuture('getVMTimelineFlags', _vmService.getVMTimelineFlags());
  }

  @override
  Future<Timestamp> getVMTimelineMicros() =>
      _trackFuture('getVMTimelineMicros', _vmService.getVMTimelineMicros());

  @override
  Future<Version> getVersion() =>
      _trackFuture('getVersion', _vmService.getVersion());

  @override
  Future<dynamic> getMemoryUsage(String isolateId) =>
      _trackFuture('getMemoryUsage', _vmService.getMemoryUsage(isolateId));

  @override
  Future invoke(
    String isolateId,
    String targetId,
    String selector,
    List<String> argumentIds, {
    bool disableBreakpoints,
  }) {
    return _trackFuture(
        'invoke $selector',
        _vmService.invoke(
          isolateId,
          targetId,
          selector,
          argumentIds,
          disableBreakpoints: disableBreakpoints,
        ));
  }

  @override
  Future<Success> kill(String isolateId) {
    return _trackFuture('kill', _vmService.kill(isolateId));
  }

  @override
  Stream<Event> get onDebugEvent => _vmService.onDebugEvent;

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
  Stream<Event> get onStderrEvent => _vmService.onStderrEvent;

  @override
  Stream<Event> get onStdoutEvent => _vmService.onStdoutEvent;

  @override
  Stream<Event> get onVMEvent => _vmService.onVMEvent;

  @override
  Future<Success> pause(String isolateId) {
    return _trackFuture('pause', _vmService.pause(isolateId));
  }

  @override
  Future<Success> registerService(String service, String alias) {
    return _trackFuture(
        'registerService $service', _vmService.registerService(service, alias));
  }

  @override
  void registerServiceCallback(String service, ServiceCallback cb) {
    return _vmService.registerServiceCallback(service, cb);
  }

  @override
  Future<ReloadReport> reloadSources(
    String isolateId, {
    bool force,
    bool pause,
    String rootLibUri,
    String packagesUri,
  }) {
    return _trackFuture(
        'reloadSources',
        _vmService.reloadSources(
          isolateId,
          force: force,
          pause: pause,
          rootLibUri: rootLibUri,
          packagesUri: packagesUri,
        ));
  }

  @override
  Future<Success> removeBreakpoint(String isolateId, String breakpointId) {
    return _trackFuture('removeBreakpoint',
        _vmService.removeBreakpoint(isolateId, breakpointId));
  }

  @override
  Future<Success> requestHeapSnapshot(
    String isolateId,
    String roots,
    bool collectGarbage,
  ) {
    return _trackFuture('requestHeapSnapshot',
        _vmService.requestHeapSnapshot(isolateId, roots, collectGarbage));
  }

  @override
  Future<Success> resume(String isolateId, {String step, int frameIndex}) {
    return _trackFuture('resume',
        _vmService.resume(isolateId, step: step, frameIndex: frameIndex));
  }

  @override
  Future<Success> setExceptionPauseMode(String isolateId, String mode) {
    return _trackFuture('setExceptionPauseMode',
        _vmService.setExceptionPauseMode(isolateId, mode));
  }

  @override
  Future<Success> setFlag(String name, String value) {
    return _trackFuture('setFlag', _vmService.setFlag(name, value));
  }

  @override
  Future<Success> setLibraryDebuggable(
    String isolateId,
    String libraryId,
    bool isDebuggable,
  ) {
    return _trackFuture('setLibraryDebuggable',
        _vmService.setLibraryDebuggable(isolateId, libraryId, isDebuggable));
  }

  @override
  Future<Success> setName(String isolateId, String name) {
    return _trackFuture('setName', _vmService.setName(isolateId, name));
  }

  @override
  Future<Success> setVMName(String name) {
    return _trackFuture('setVMName', _vmService.setVMName(name));
  }

  @override
  Future<Success> setVMTimelineFlags(List<String> recordedStreams) async {
    if (await isProtocolVersionLessThan(major: 3, minor: 19)) {
      final response = await _trackFuture(
          'setVMTimelineFlags',
          callMethod(
            '_setVMTimelineFlags',
            args: {'recordedStreams': recordedStreams},
          ));
      return response as Success;
    }
    return _trackFuture(
      'setVMTimelineFlags',
      _vmService.setVMTimelineFlags(recordedStreams),
    );
  }

  @override
  Future<Success> streamCancel(String streamId) {
    _activeStreams.remove(streamId);
    return _trackFuture('streamCancel', _vmService.streamCancel(streamId));
  }

  // We tweaked this method so that we do not try to listen to the same stream
  // twice. This was causing an issue with the test environment and this change
  // should not affect the run environment.
  @override
  Future<Success> streamListen(String streamId) {
    if (!_activeStreams.containsKey(streamId)) {
      final Future<Success> future =
          _trackFuture('streamListen', _vmService.streamListen(streamId));
      _activeStreams[streamId] = future;
      return future;
    } else {
      return _activeStreams[streamId];
    }
  }

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

  Future<bool> isProtocolVersionLessThan({
    @required int major,
    @required int minor,
  }) async {
    _protocolVersion ??= await getVersion();
    return protocolVersionLessThan(major: major, minor: minor);
  }

  bool protocolVersionLessThan({
    @required int major,
    @required int minor,
  }) {
    assert(_protocolVersion != null);
    return _protocolVersion.major < major ||
        (_protocolVersion.major == major && _protocolVersion.minor < minor);
  }

  Future<T> _trackFuture<T>(String name, Future<T> future) {
    if (!trackFutures) {
      return future;
    }
    final trackedFuture = new TrackedFuture(name, future);
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

    future.then(
      (value) => futureComplete(),
      onError: (error) => futureComplete(),
    );
    return future;
  }
}

class TrackedFuture<T> {
  TrackedFuture(this.name, this.future);

  final String name;
  final Future<T> future;
}
