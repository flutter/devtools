import 'dart:async';
import 'package:vm_service_lib/vm_service_lib.dart';

class VmServiceWrapper implements VmService {
  VmServiceWrapper(this.vmService);

  VmServiceWrapper.fromNewVmService(
      Stream<dynamic> /*String|List<int>*/ inStream,
      void writeMessage(String message),
      {Log log,
      DisposeHandler disposeHandler}) {
    vmService = new VmService(inStream, writeMessage,
        log: log, disposeHandler: disposeHandler);
  }

  VmService vmService;
  Set<String> activeStreams = Set();
  Set<Future<Object>> activeFutures = Set();
  Completer<bool> noPendingFutures = new Completer<bool>();

  @override
  Future<Breakpoint> addBreakpoint(String isolateId, String scriptId, int line,
          {int column}) =>
      _trackFuture(
          vmService.addBreakpoint(isolateId, scriptId, line, column: column));

  @override
  Future<Breakpoint> addBreakpointAtEntry(
          String isolateId, String functionId) =>
      _trackFuture(vmService.addBreakpointAtEntry(isolateId, functionId));

  @override
  Future<Breakpoint> addBreakpointWithScriptUri(
          String isolateId, String scriptUri, int line, {int column}) =>
      _trackFuture(vmService.addBreakpointWithScriptUri(
          isolateId, scriptUri, line,
          column: column));

  @override
  Future<Response> callMethod(String method, {String isolateId, Map args}) =>
      _trackFuture(
          vmService.callMethod(method, isolateId: isolateId, args: args));

  @override
  Future<Response> callServiceExtension(String method,
          {String isolateId, Map args}) =>
      _trackFuture(vmService.callServiceExtension(method,
          isolateId: isolateId, args: args));

  @override
  Future<Success> clearCpuProfile(String isolateId) =>
      _trackFuture(vmService.clearCpuProfile(isolateId));

  @override
  Future<Success> clearVMTimeline() => _trackFuture(vmService.clearVMTimeline());

  @override
  Future<Success> collectAllGarbage(String isolateId) =>
      _trackFuture(vmService.collectAllGarbage(isolateId));

  @override
  void dispose() => vmService.dispose();

  @override
  Future evaluate(String isolateId, String targetId, String expression,
          {Map<String, String> scope}) =>
      _trackFuture(
          vmService.evaluate(isolateId, targetId, expression, scope: scope));

  @override
  Future evaluateInFrame(String isolateId, int frameIndex, String expression,
          {Map<String, String> scope}) =>
      _trackFuture(vmService.evaluateInFrame(isolateId, frameIndex, expression,
          scope: scope));

  @override
  Future<AllocationProfile> getAllocationProfile(String isolateId,
          {String gc, bool reset}) =>
      _trackFuture(vmService.getAllocationProfile(isolateId));

  @override
  Future<CpuProfile> getCpuProfile(String isolateId, String tags) =>
      _trackFuture(vmService.getCpuProfile(isolateId, tags));

  @override
  Future<FlagList> getFlagList() => _trackFuture(vmService.getFlagList());

  @override
  Future<ObjRef> getInstances(String isolateId, String classId, int limit) =>
      _trackFuture(vmService.getInstances(isolateId, classId, limit));

  @override
  Future getIsolate(String isolateId) =>
      _trackFuture(vmService.getIsolate(isolateId));

  @override
  Future getObject(String isolateId, String objectId,
          {int offset, int count}) =>
      _trackFuture(vmService.getObject(isolateId, objectId));

  @override
  Future<ScriptList> getScripts(String isolateId) =>
      _trackFuture(vmService.getScripts(isolateId));

  @override
  Future<SourceReport> getSourceReport(
          String isolateId, List<SourceReportKind> reports,
          {String scriptId,
          int tokenPos,
          int endTokenPos,
          bool forceCompile}) =>
      _trackFuture(vmService.getSourceReport(isolateId, reports,
          scriptId: scriptId,
          tokenPos: tokenPos,
          endTokenPos: endTokenPos,
          forceCompile: forceCompile));

  @override
  Future<Stack> getStack(String isolateId) =>
      _trackFuture(vmService.getStack(isolateId));

  @override
  Future<VM> getVM() => _trackFuture(vmService.getVM());

  @override
  Future<Response> getVMTimeline() => _trackFuture(vmService.getVMTimeline());

  @override
  Future<Version> getVersion() => _trackFuture(vmService.getVersion());

  @override
  Future invoke(String isolateId, String targetId, String selector,
          List<String> argumentIds) =>
      _trackFuture(vmService.invoke(isolateId, targetId, selector, argumentIds));

  @override
  Future<Success> kill(String isolateId) =>
      _trackFuture(vmService.kill(isolateId));

  @override
  Stream<Event> get onDebugEvent => vmService.onDebugEvent;

  @override
  Stream<Event> onEvent(String streamName) => vmService.onEvent(streamName);

  @override
  Stream<Event> get onExtensionEvent => vmService.onExtensionEvent;

  @override
  Stream<Event> get onGCEvent => vmService.onGCEvent;

  @override
  Stream<Event> get onGraphEvent => vmService.onGraphEvent;

  @override
  Stream<Event> get onIsolateEvent => vmService.onIsolateEvent;

  @override
  Stream<String> get onReceive => vmService.onReceive;

  @override
  Stream<String> get onSend => vmService.onSend;

  @override
  Stream<Event> get onServiceEvent => vmService.onServiceEvent;

  @override
  Stream<Event> get onStderrEvent => vmService.onStderrEvent;

  @override
  Stream<Event> get onStdoutEvent => vmService.onStdoutEvent;

  @override
  Stream<Event> get onVMEvent => vmService.onVMEvent;

  @override
  Future<Success> pause(String isolateId) => _trackFuture(vmService.pause(isolateId));

  @override
  Future<Success> registerService(String service, String alias) =>
      _trackFuture(vmService.registerService(service, alias));

  @override
  void registerServiceCallback(String service, ServiceCallback cb) =>
      vmService.registerServiceCallback(service, cb);

  @override
  Future<ReloadReport> reloadSources(String isolateId,
          {bool force, bool pause, String rootLibUri, String packagesUri}) =>
      _trackFuture(vmService.reloadSources(isolateId,
          force: force,
          pause: pause,
          rootLibUri: rootLibUri,
          packagesUri: packagesUri));

  @override
  Future<Success> removeBreakpoint(String isolateId, String breakpointId) =>
      _trackFuture(vmService.removeBreakpoint(isolateId, breakpointId));

  @override
  Future<Success> requestHeapSnapshot(
          String isolateId, String roots, bool collectGarbage) =>
      _trackFuture(
          vmService.requestHeapSnapshot(isolateId, roots, collectGarbage));

  @override
  Future<Success> resume(String isolateId, {String step, int frameIndex}) =>
      _trackFuture(
          vmService.resume(isolateId, step: step, frameIndex: frameIndex));

  @override
  Future<Success> setExceptionPauseMode(String isolateId, String mode) =>
      _trackFuture(vmService.setExceptionPauseMode(isolateId, mode));

  @override
  Future<Success> setFlag(String name, String value) =>
      _trackFuture(vmService.setFlag(name, value));

  @override
  Future<Success> setLibraryDebuggable(
          String isolateId, String libraryId, bool isDebuggable) =>
      _trackFuture(
          vmService.setLibraryDebuggable(isolateId, libraryId, isDebuggable));

  @override
  Future<Success> setName(String isolateId, String name) =>
      _trackFuture(vmService.setName(isolateId, name));

  @override
  Future<Success> setVMName(String name) =>
      _trackFuture(vmService.setVMName(name));

  @override
  Future<Success> setVMTimelineFlags(List<String> recordedStreams) =>
      _trackFuture(vmService.setVMTimelineFlags(recordedStreams));

  @override
  Future<Success> streamCancel(String streamId) {
    activeStreams.remove(streamId);
    return _trackFuture(vmService.streamCancel(streamId));
  }

  @override
  Future<Success> streamListen(String streamId) {
    Future<Success> future;
    if (!activeStreams.contains(streamId)) {
      future = _trackFuture(vmService.streamListen(streamId));
    }
    activeStreams.add(streamId);
    return future;
  }

  Future<T> _trackFuture<T>(Future<T> future) {
    activeFutures.add(future);
    future.whenComplete(() {
      activeFutures.remove(future);
      if (activeFutures.isEmpty && !noPendingFutures.isCompleted) {
        noPendingFutures.complete(true);
      } else {
        noPendingFutures = new Completer<bool>();
      }
    });
    return future;
  }
}
