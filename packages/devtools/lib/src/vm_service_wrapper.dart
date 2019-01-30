// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:vm_service_lib/vm_service_lib.dart';

class VmServiceWrapper implements VmService {
  VmServiceWrapper(this._vmService);

  VmServiceWrapper.fromNewVmService(
    Stream<dynamic> /*String|List<int>*/ inStream,
    void writeMessage(String message), {
    Log log,
    DisposeHandler disposeHandler,
  }) {
    _vmService = VmService(inStream, writeMessage,
        log: log, disposeHandler: disposeHandler);
  }

  VmService _vmService;
  final Map<String, Future<Success>> _activeStreams = {};
  final Set<Future<Object>> _activeFutures = Set();
  Completer<bool> allFuturesCompleted = Completer<bool>();

  @override
  Future<Breakpoint> addBreakpoint(
    String isolateId,
    String scriptId,
    int line, {
    int column,
  }) {
    return _trackFuture(
        _vmService.addBreakpoint(isolateId, scriptId, line, column: column));
  }

  @override
  Future<Breakpoint> addBreakpointAtEntry(String isolateId, String functionId) {
    return _trackFuture(_vmService.addBreakpointAtEntry(isolateId, functionId));
  }

  @override
  Future<Breakpoint> addBreakpointWithScriptUri(
    String isolateId,
    String scriptUri,
    int line, {
    int column,
  }) {
    return _trackFuture(_vmService.addBreakpointWithScriptUri(
      isolateId,
      scriptUri,
      line,
      column: column,
    ));
  }

  @override
  Future<Response> callMethod(String method, {String isolateId, Map args}) {
    return _trackFuture(
        _vmService.callMethod(method, isolateId: isolateId, args: args));
  }

  @override
  Future<Response> callServiceExtension(
    String method, {
    String isolateId,
    Map args,
  }) {
    return _trackFuture(_vmService.callServiceExtension(
      method,
      isolateId: isolateId,
      args: args,
    ));
  }

  @override
  Future<Success> clearCpuProfile(String isolateId) {
    return _trackFuture(_vmService.clearCpuProfile(isolateId));
  }

  @override
  Future<Success> clearVMTimeline() {
    return _trackFuture(_vmService.clearVMTimeline());
  }

  @override
  Future<Success> collectAllGarbage(String isolateId) {
    return _trackFuture(_vmService.collectAllGarbage(isolateId));
  }

  @override
  void dispose() => _vmService.dispose();

  @override
  Future evaluate(
    String isolateId,
    String targetId,
    String expression, {
    Map<String, String> scope,
  }) {
    return _trackFuture(
        _vmService.evaluate(isolateId, targetId, expression, scope: scope));
  }

  @override
  Future evaluateInFrame(
    String isolateId,
    int frameIndex,
    String expression, {
    Map<String, String> scope,
  }) {
    return _trackFuture(_vmService
        .evaluateInFrame(isolateId, frameIndex, expression, scope: scope));
  }

  @override
  Future<AllocationProfile> getAllocationProfile(
    String isolateId, {
    String gc,
    bool reset,
  }) {
    return _trackFuture(_vmService.getAllocationProfile(isolateId));
  }

  @override
  Future<CpuProfile> getCpuProfile(String isolateId, String tags) {
    return _trackFuture(_vmService.getCpuProfile(isolateId, tags));
  }

  @override
  Future<FlagList> getFlagList() => _trackFuture(_vmService.getFlagList());

  @override
  Future<ObjRef> getInstances(String isolateId, String classId, int limit) {
    return _trackFuture(_vmService.getInstances(isolateId, classId, limit));
  }

  @override
  Future getIsolate(String isolateId) {
    return _trackFuture(_vmService.getIsolate(isolateId));
  }

  @override
  Future<Object> getObject(
    String isolateId,
    String objectId, {
    int offset,
    int count,
  }) {
    return _trackFuture(_vmService.getObject(isolateId, objectId));
  }

  @override
  Future<ScriptList> getScripts(String isolateId) {
    return _trackFuture(_vmService.getScripts(isolateId));
  }

  @override
  Future<SourceReport> getSourceReport(
    String isolateId,
    List<SourceReportKind> reports, {
    String scriptId,
    int tokenPos,
    int endTokenPos,
    bool forceCompile,
  }) {
    return _trackFuture(_vmService.getSourceReport(
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
    return _trackFuture(_vmService.getStack(isolateId));
  }

  @override
  Future<VM> getVM() => _trackFuture(_vmService.getVM());

  @override
  Future<Response> getVMTimeline() => _trackFuture(_vmService.getVMTimeline());

  @override
  Future<Version> getVersion() => _trackFuture(_vmService.getVersion());

  @override
  Future invoke(
    String isolateId,
    String targetId,
    String selector,
    List<String> argumentIds,
  ) {
    return _trackFuture(
        _vmService.invoke(isolateId, targetId, selector, argumentIds));
  }

  @override
  Future<Success> kill(String isolateId) {
    return _trackFuture(_vmService.kill(isolateId));
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
  Stream<Event> get onGraphEvent => _vmService.onGraphEvent;

  @override
  Stream<Event> get onIsolateEvent => _vmService.onIsolateEvent;

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
  Future<Success> pause(String isolateId) {
    return _trackFuture(_vmService.pause(isolateId));
  }

  @override
  Future<Success> registerService(String service, String alias) {
    return _trackFuture(_vmService.registerService(service, alias));
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
    return _trackFuture(_vmService.reloadSources(
      isolateId,
      force: force,
      pause: pause,
      rootLibUri: rootLibUri,
      packagesUri: packagesUri,
    ));
  }

  @override
  Future<Success> removeBreakpoint(String isolateId, String breakpointId) {
    return _trackFuture(_vmService.removeBreakpoint(isolateId, breakpointId));
  }

  @override
  Future<Success> requestHeapSnapshot(
    String isolateId,
    String roots,
    bool collectGarbage,
  ) {
    return _trackFuture(
        _vmService.requestHeapSnapshot(isolateId, roots, collectGarbage));
  }

  @override
  Future<Success> resume(String isolateId, {String step, int frameIndex}) {
    return _trackFuture(
        _vmService.resume(isolateId, step: step, frameIndex: frameIndex));
  }

  @override
  Future<Success> setExceptionPauseMode(String isolateId, String mode) {
    return _trackFuture(_vmService.setExceptionPauseMode(isolateId, mode));
  }

  @override
  Future<Success> setFlag(String name, String value) {
    return _trackFuture(_vmService.setFlag(name, value));
  }

  @override
  Future<Success> setLibraryDebuggable(
    String isolateId,
    String libraryId,
    bool isDebuggable,
  ) {
    return _trackFuture(
        _vmService.setLibraryDebuggable(isolateId, libraryId, isDebuggable));
  }

  @override
  Future<Success> setName(String isolateId, String name) {
    return _trackFuture(_vmService.setName(isolateId, name));
  }

  @override
  Future<Success> setVMName(String name) {
    return _trackFuture(_vmService.setVMName(name));
  }

  @override
  Future<Success> setVMTimelineFlags(List<String> recordedStreams) {
    return _trackFuture(_vmService.setVMTimelineFlags(recordedStreams));
  }

  @override
  Future<Success> streamCancel(String streamId) {
    _activeStreams.remove(streamId);
    return _trackFuture(_vmService.streamCancel(streamId));
  }

  // We tweaked this method so that we do not try to listen to the same stream
  // twice. This was causing an issue with the test environment and this change
  // should not affect the run environment.
  @override
  Future<Success> streamListen(String streamId) {
    if (!_activeStreams.containsKey(streamId)) {
      final Future<Success> future =
          _trackFuture(_vmService.streamListen(streamId));
      _activeStreams[streamId] = future;
      return future;
    } else {
      return _activeStreams[streamId];
    }
  }

  Future<T> _trackFuture<T>(Future<T> future) {
    if (allFuturesCompleted.isCompleted) {
      allFuturesCompleted = Completer<bool>();
    }
    _activeFutures.add(future);
    future.whenComplete(() {
      _activeFutures.remove(future);
      if (_activeFutures.isEmpty && !allFuturesCompleted.isCompleted) {
        allFuturesCompleted.complete(true);
      }
    });
    return future;
  }
}
