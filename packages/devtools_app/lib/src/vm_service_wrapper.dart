// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import 'profiler/cpu_profile_model.dart';
import 'version.dart';

class VmServiceWrapper implements VmService {
  VmServiceWrapper(
    this._vmService,
    this._connectedUri, {
    this.trackFutures = false,
  });

  VmServiceWrapper.fromNewVmService(
    Stream<dynamic> /*String|List<int>*/ inStream,
    void writeMessage(String message),
    this._connectedUri, {
    Log log,
    DisposeHandler disposeHandler,
    this.trackFutures = false,
  }) {
    _vmService = VmService(
      inStream,
      writeMessage,
      log: log,
      disposeHandler: disposeHandler,
    );
  }

  VmService _vmService;
  Version _protocolVersion;
  Version _dartIoVersion;

  Uri get connectedUri => _connectedUri;
  final Uri _connectedUri;

  final bool trackFutures;
  final Map<String, Future<Success>> _activeStreams = {};

  final Set<TrackedFuture<Object>> activeFutures = {};
  Completer<bool> _allFuturesCompleter = Completer<bool>()
    // Mark the future as completed by default so if we don't track any
    // futures but someone tries to wait on [allFuturesCompleted] they don't
    // hang. The first tracked future will replace this with a new completer.
    ..complete(true);

  Future<void> get allFuturesCompleted => _allFuturesCompleter.future;

  /// Executes `callback` for each isolate, and waiting for all callbacks to
  /// finish before completing.
  Future<void> forEachIsolate(
      Future<void> Function(IsolateRef) callback) async {
    final vm = await _vmService.getVM();
    final futures = <Future>[];
    for (final isolate in vm.isolates) {
      futures.add(callback(isolate));
    }
    await Future.wait(futures);
  }

  @override
  Future<Breakpoint> addBreakpoint(
    String isolateId,
    String scriptId,
    int line, {
    int column,
  }) {
    return trackFuture('addBreakpoint',
        _vmService.addBreakpoint(isolateId, scriptId, line, column: column));
  }

  @override
  Future<Breakpoint> addBreakpointAtEntry(String isolateId, String functionId) {
    return trackFuture('addBreakpointAtEntry',
        _vmService.addBreakpointAtEntry(isolateId, functionId));
  }

  @override
  Future<Breakpoint> addBreakpointWithScriptUri(
    String isolateId,
    String scriptUri,
    int line, {
    int column,
  }) {
    return trackFuture(
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
    return trackFuture('callMethod $method',
        _vmService.callMethod(method, isolateId: isolateId, args: args));
  }

  @override
  Future<Response> callServiceExtension(
    String method, {
    String isolateId,
    Map args,
  }) {
    return trackFuture(
        'callServiceExtension $method',
        _vmService.callServiceExtension(
          method,
          isolateId: isolateId,
          args: args,
        ));
  }

  @override
  Future<Success> clearCpuSamples(String isolateId) async {
    if (await isProtocolVersionSupported(
        supportedVersion: SemanticVersion(major: 3, minor: 27))) {
      return trackFuture(
        'clearCpuSamples',
        _vmService.clearCpuSamples(isolateId),
      );
    } else {
      final response = await trackFuture(
        'clearCpuSamples',
        callMethod('_clearCpuProfile', isolateId: isolateId),
      );
      return response as Success;
    }
  }

  @override
  Future<Success> clearVMTimeline() async {
    if (await isProtocolVersionSupported(
        supportedVersion: SemanticVersion(major: 3, minor: 19))) {
      return trackFuture('clearVMTimeline', _vmService.clearVMTimeline());
    } else {
      final response =
          await trackFuture('clearVMTimeline', callMethod('_clearVMTimeline'));
      return response as Success;
    }
  }

  @override
  Future get onDone => _vmService.onDone;

  @override
  void dispose() => _vmService.dispose();

  @override
  Future<Response> evaluate(
    String isolateId,
    String targetId,
    String expression, {
    Map<String, String> scope,
    bool disableBreakpoints,
  }) {
    return trackFuture(
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
  Future<Response> evaluateInFrame(
    String isolateId,
    int frameIndex,
    String expression, {
    Map<String, String> scope,
    bool disableBreakpoints,
  }) {
    return trackFuture(
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
    if (await isProtocolVersionSupported(
        supportedVersion: SemanticVersion(major: 3, minor: 18))) {
      return trackFuture(
        'getAllocationProfile',
        _vmService.getAllocationProfile(isolateId, reset: reset, gc: gc),
      );
    } else {
      final Map<String, dynamic> args = {};
      if (gc != null && gc) {
        args['gc'] = 'full';
      }
      if (reset != null && reset) {
        args['reset'] = reset;
      }
      final response = await trackFuture(
        'getAllocationProfile',
        callMethod('_getAllocationProfile', isolateId: isolateId, args: args),
      );
      return AllocationProfile.parse(response.json);
    }
  }

  @override
  Future<CpuSamples> getCpuSamples(
      String isolateId, int timeOriginMicros, int timeExtentMicros) async {
    return trackFuture(
        'getCpuSamples',
        _vmService.getCpuSamples(
          isolateId,
          timeOriginMicros,
          timeExtentMicros,
        ));
  }

  Future<CpuProfileData> getCpuProfileTimeline(
      String isolateId, int origin, int extent) async {
    if (await isProtocolVersionSupported(
        supportedVersion: SemanticVersion(major: 3, minor: 27))) {
      // As of service protocol version 3.27 _getCpuProfileTimeline does not exist
      // and has been replaced by getCpuSamples. We need to do some processing to
      // get back to the format we expect.
      final cpuSamples = await getCpuSamples(isolateId, origin, extent);

      // The root ID is associated with an artificial frame / node that is the root
      // of all stacks, regardless of entrypoint. This should never be seen in the
      // final output from this method.
      const int kRootId = 0;
      int nextId = kRootId;
      final traceObject = <String, dynamic>{
        CpuProfileData.sampleCountKey: cpuSamples.sampleCount,
        CpuProfileData.samplePeriodKey: cpuSamples.samplePeriod,
        CpuProfileData.stackDepthKey: cpuSamples.maxStackDepth,
        CpuProfileData.timeOriginKey: cpuSamples.timeOriginMicros,
        CpuProfileData.timeExtentKey: cpuSamples.timeExtentMicros,
        CpuProfileData.stackFramesKey: {},
        CpuProfileData.traceEventsKey: [],
      };

      void processStackFrame({
        @required _CpuProfileTimelineTree current,
        @required _CpuProfileTimelineTree parent,
      }) {
        final id = nextId++;
        current.frameId = id;

        // Skip the root.
        if (id != kRootId) {
          final key = '$isolateId-$id';
          traceObject[CpuProfileData.stackFramesKey][key] = {
            CpuProfileData.categoryKey: 'Dart',
            CpuProfileData.nameKey: current.name,
            CpuProfileData.resolvedUrlKey: current.resolvedUrl,
            if (parent != null && parent.frameId != 0)
              CpuProfileData.parentIdKey: '$isolateId-${parent.frameId}',
          };
        }
        for (final child in current.children) {
          processStackFrame(current: child, parent: current);
        }
      }

      final root = _CpuProfileTimelineTree.fromCpuSamples(cpuSamples);
      processStackFrame(current: root, parent: null);

      // Build the trace events.
      for (final sample in cpuSamples.samples) {
        final tree = _CpuProfileTimelineTree.getTreeFromSample(sample);
        // Skip the root.
        if (tree.frameId == kRootId) {
          continue;
        }
        traceObject[CpuProfileData.traceEventsKey].add({
          'ph': 'P', // kind = sample event
          'name': '', // Blank to keep about:tracing happy
          'pid': cpuSamples.pid,
          'tid': sample.tid,
          'ts': sample.timestamp,
          'cat': 'Dart',
          CpuProfileData.stackFrameIdKey: '$isolateId-${tree.frameId}',
        });
      }
      return CpuProfileData.parse(traceObject);
    } else {
      return trackFuture(
          'getCpuProfileTimeline',
          callMethod(
            '_getCpuProfileTimeline',
            isolateId: isolateId,
            args: {
              'tags': 'None',
              'timeOriginMicros': origin,
              'timeExtentMicros': extent,
            },
          )).then((Response response) => CpuProfileData.parse(response.json));
    }
  }

  @override
  Future<FlagList> getFlagList() =>
      trackFuture('getFlagList', _vmService.getFlagList());

  @override
  Future<InstanceSet> getInstances(
    String isolateId,
    String objectId,
    int limit, {
    String classId,
  }) async {
    if (await isProtocolVersionSupported(
        supportedVersion: SemanticVersion(major: 3, minor: 20))) {
      return trackFuture(
        'getInstances',
        _vmService.getInstances(isolateId, objectId, limit),
      );
    } else {
      final response = await trackFuture(
        'getInstances',
        callMethod('_getInstances', args: {
          'isolateId': isolateId,
          'classId': classId,
          'limit': limit,
        }),
      );
      return InstanceSet.parse(response.json);
    }
  }

  @override
  Future<Isolate> getIsolate(String isolateId) {
    return trackFuture('getIsolate', _vmService.getIsolate(isolateId));
  }

  @override
  Future<IsolateGroup> getIsolateGroup(String isolateGroupId) {
    return trackFuture(
        'getIsolateGroup', _vmService.getIsolateGroup(isolateGroupId));
  }

  @override
  Future<MemoryUsage> getIsolateGroupMemoryUsage(String isolateGroupId) {
    return trackFuture('getIsolateGroupMemoryUsage',
        _vmService.getIsolateGroupMemoryUsage(isolateGroupId));
  }

  @override
  Future<Obj> getObject(
    String isolateId,
    String objectId, {
    int offset,
    int count,
  }) {
    return trackFuture('getObject', _vmService.getObject(isolateId, objectId));
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
    String scriptId,
    int tokenPos,
    int endTokenPos,
    bool forceCompile,
  }) {
    return trackFuture(
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
  Future<Stack> getStack(String isolateId, {int limit}) {
    return trackFuture(
        'getStack', _vmService.getStack(isolateId, limit: limit));
  }

  @override
  Future<VM> getVM() => trackFuture('getVM', _vmService.getVM());

  @override
  Future<Timeline> getVMTimeline({
    int timeOriginMicros,
    int timeExtentMicros,
  }) async {
    if (await isProtocolVersionSupported(
        supportedVersion: SemanticVersion(major: 3, minor: 19))) {
      return trackFuture(
        'getVMTimeline',
        _vmService.getVMTimeline(
          timeOriginMicros: timeOriginMicros,
          timeExtentMicros: timeExtentMicros,
        ),
      );
    } else {
      final Response response =
          await trackFuture('getVMTimeline', callMethod('_getVMTimeline'));
      return Timeline.parse(response.json);
    }
  }

  // TODO(kenz): move this method to
  // https://github.com/dart-lang/sdk/blob/master/pkg/vm_service/lib/src/dart_io_extensions.dart
  Future<bool> isHttpTimelineLoggingAvailable(String isolateId) async {
    final Isolate isolate = await getIsolate(isolateId);
    if (await isDartIoVersionSupported(
      supportedVersion: SemanticVersion(major: 1, minor: 3),
      isolateId: isolateId,
    )) {
      return isolate.extensionRPCs
          .contains('ext.dart.io.httpEnableTimelineLogging');
    } else {
      return isolate.extensionRPCs
          .contains('ext.dart.io.setHttpEnableTimelineLogging');
    }
  }

  Future<HttpTimelineLoggingState> httpEnableTimelineLogging(
    String isolateId, [
    bool enabled,
  ]) async {
    assert(await isHttpTimelineLoggingAvailable(isolateId));
    if (await isDartIoVersionSupported(
      supportedVersion: SemanticVersion(major: 1, minor: 3),
      isolateId: isolateId,
    )) {
      return trackFuture('httpEnableTimelineLogging',
          _vmService.httpEnableTimelineLogging(isolateId, enabled));
    } else {
      if (enabled == null) {
        return trackFuture(
            'getHttpEnableTimelineLogging',
            // ignore: deprecated_member_use
            _vmService.getHttpEnableTimelineLogging(isolateId));
      } else {
        await trackFuture(
            'setHttpEnableTimelineLogging',
            // ignore: deprecated_member_use
            _vmService.setHttpEnableTimelineLogging(isolateId, enabled));
        return HttpTimelineLoggingState(enabled: enabled);
      }
    }
  }

  // TODO(kenz): move this method to
  // https://github.com/dart-lang/sdk/blob/master/pkg/vm_service/lib/src/dart_io_extensions.dart
  Future<bool> isSocketProfilingAvailable(String isolateId) async {
    final Isolate isolate = await getIsolate(isolateId);
    return isolate.extensionRPCs.contains('ext.dart.io.getSocketProfile');
  }

  Future<SocketProfilingState> socketProfilingEnabled(
    String isolateId, [
    bool enabled,
  ]) async {
    assert(await isSocketProfilingAvailable(isolateId));
    if (await isDartIoVersionSupported(
      supportedVersion: SemanticVersion(major: 1, minor: 5),
      isolateId: isolateId,
    )) {
      return trackFuture('socketProfilingEnabled',
          _vmService.socketProfilingEnabled(isolateId, enabled));
    } else {
      if (enabled == null) {
        // Before Dart IO version 1.5, there was not a getter, so return the
        // default state of false.
        return Future.value(SocketProfilingState(enabled: false));
      } else {
        if (enabled) {
          await trackFuture(
            'startSocketProfiling',
            // ignore: deprecated_member_use
            _vmService.startSocketProfiling(isolateId),
          );
        } else {
          await trackFuture(
            'pauseSocketProfiling',
            // ignore: deprecated_member_use
            _vmService.pauseSocketProfiling(isolateId),
          );
        }
        return SocketProfilingState(enabled: enabled);
      }
    }
  }

  Future<Success> clearSocketProfile(String isolateId) async {
    assert(await isSocketProfilingAvailable(isolateId));
    return trackFuture(
        'clearSocketProfile', _vmService.clearSocketProfile(isolateId));
  }

  Future<SocketProfile> getSocketProfile(String isolateId) async {
    assert(await isSocketProfilingAvailable(isolateId));
    return trackFuture(
        'getSocketProfile', _vmService.getSocketProfile(isolateId));
  }

  @override
  Future<TimelineFlags> getVMTimelineFlags() {
    return trackFuture('getVMTimelineFlags', _vmService.getVMTimelineFlags());
  }

  @override
  Future<Timestamp> getVMTimelineMicros() async {
    if (await isProtocolVersionSupported(
        supportedVersion: SemanticVersion(major: 3, minor: 21))) {
      return trackFuture(
        'getVMTimelineMicros',
        _vmService.getVMTimelineMicros(),
      );
    } else {
      return null;
    }
  }

  @override
  Future<Version> getVersion() =>
      trackFuture('getVersion', _vmService.getVersion());

  Future<Version> getDartIOVersion(String isolateId) =>
      trackFuture('_getDartIOVersion', _vmService.getDartIOVersion(isolateId));

  @override
  Future<MemoryUsage> getMemoryUsage(String isolateId) =>
      trackFuture('getMemoryUsage', _vmService.getMemoryUsage(isolateId));

  @override
  Future<Response> invoke(
    String isolateId,
    String targetId,
    String selector,
    List<String> argumentIds, {
    bool disableBreakpoints,
  }) {
    return trackFuture(
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
    // Handle registerService method name change based on protocol version.
    final registerServiceMethodName = await isProtocolVersionSupported(
            supportedVersion: SemanticVersion(major: 3, minor: 22))
        ? 'registerService'
        : '_registerService';

    final response = await trackFuture(
      '$registerServiceMethodName $service',
      callMethod(registerServiceMethodName,
          args: {'service': service, 'alias': alias}),
    );

    return response as Success;

    // TODO(dantup): When we no longer need to support clients on older VMs
    // that don't support public registerService (added in July 2019, VM service
    // v3.22) we can replace the above with a direct call to vm_service_lib's
    // registerService (as long as we're pinned to version >= 3.22.0).
    // return trackFuture(
    //     'registerService $service', _vmService.registerService(service, alias));
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
    return trackFuture(
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
    return trackFuture('removeBreakpoint',
        _vmService.removeBreakpoint(isolateId, breakpointId));
  }

  @override
  Future<Success> resume(String isolateId, {String step, int frameIndex}) {
    return trackFuture('resume',
        _vmService.resume(isolateId, step: step, frameIndex: frameIndex));
  }

  @override
  Future<Success> setExceptionPauseMode(String isolateId, String mode) {
    return trackFuture('setExceptionPauseMode',
        _vmService.setExceptionPauseMode(isolateId, mode));
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
    return trackFuture('setLibraryDebuggable',
        _vmService.setLibraryDebuggable(isolateId, libraryId, isDebuggable));
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
    if (await isProtocolVersionSupported(
        supportedVersion: SemanticVersion(major: 3, minor: 19))) {
      return trackFuture(
        'setVMTimelineFlags',
        _vmService.setVMTimelineFlags(recordedStreams),
      );
    } else {
      final response = await trackFuture(
          'setVMTimelineFlags',
          callMethod(
            '_setVMTimelineFlags',
            args: {'recordedStreams': recordedStreams},
          ));
      return response as Success;
    }
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
      return _activeStreams[streamId];
    }
  }

  @override
  Future<InboundReferences> getInboundReferences(
    String isolateId,
    String targetId,
    int limit,
  ) async {
    if (await isProtocolVersionSupported(
        supportedVersion: SemanticVersion(major: 3, minor: 25))) {
      return trackFuture(
        'getInboundReferences',
        _vmService.getInboundReferences(isolateId, targetId, limit),
      );
    } else {
      return trackFuture(
        'getInboundReferences',
        _vmService.callMethod(
          '_getInboundReferences',
          isolateId: isolateId,
          args: {'targetId': targetId, 'limit': limit},
        ),
      );
    }
  }

  @override
  Future<RetainingPath> getRetainingPath(
          String isolateId, String targetId, int limit) =>
      trackFuture('getRetainingPath',
          _vmService.getRetainingPath(isolateId, targetId, limit));

  @override
  Future<ProcessMemoryUsage> getProcessMemoryUsage() {
    return trackFuture(
        'getProcessMemoryUsage', _vmService.getProcessMemoryUsage());
  }

  @override
  Future<ProtocolList> getSupportedProtocols() async {
    if (await isProtocolVersionSupported(
        supportedVersion: SemanticVersion(major: 3, minor: 35))) {
      return trackFuture(
        'getSupportedProtocols',
        _vmService.getSupportedProtocols(),
      );
    } else {
      return null;
    }
  }

  @override
  Future<PortList> getPorts(String isolateId) async {
    if (await isProtocolVersionSupported(
        supportedVersion: SemanticVersion(major: 3, minor: 42))) {
      return trackFuture(
        'getPorts',
        _vmService.getPorts(isolateId),
      );
    } else {
      return null;
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

  Future<bool> isProtocolVersionSupported({
    @required SemanticVersion supportedVersion,
  }) async {
    _protocolVersion ??= await getVersion();
    return isProtocolVersionSupportedNow(supportedVersion: supportedVersion);
  }

  bool isProtocolVersionSupportedNow({
    @required SemanticVersion supportedVersion,
  }) {
    return _versionSupported(
      version: _protocolVersion,
      supportedVersion: supportedVersion,
    );
  }

  bool _versionSupported({
    @required Version version,
    @required SemanticVersion supportedVersion,
  }) {
    return SemanticVersion(
      major: version.major,
      minor: version.minor,
    ).isSupported(supportedVersion: supportedVersion);
  }

  Future<bool> isDartIoVersionSupported({
    @required SemanticVersion supportedVersion,
    @required String isolateId,
  }) async {
    _dartIoVersion ??= await getDartIOVersion(isolateId);
    return _versionSupported(
      version: _dartIoVersion,
      supportedVersion: supportedVersion,
    );
  }

  /// Retrieves the full string value of a [stringRef].
  ///
  /// The string value stored with the [stringRef] is returned unless the value
  /// is truncated, in which an extra getObject call is issued to return the
  /// value. If the [stringRef] has expired so the full string is unavailable,
  /// [onUnavailable] is called to return how the truncated value should be
  /// displayed. If [onUnavailable] is not specified, an exception is thrown
  /// if the full value cannot be retrieved.
  Future<String> retrieveFullStringValue(
    String isolateId,
    InstanceRef stringRef, {
    String onUnavailable(String truncatedValue),
  }) async {
    if (stringRef == null) return null;
    if (stringRef.valueAsStringIsTruncated != true)
      return stringRef.valueAsString;

    final result = await getObject(
      isolateId,
      stringRef.id,
      offset: 0,
      count: stringRef.length,
    );
    if (result is Instance) {
      return result.valueAsString;
    } else if (onUnavailable != null) {
      return onUnavailable(stringRef.valueAsString);
    } else {
      throw Exception(
          'The full string for "{stringRef.valueAsString}..." is unavailable');
    }
  }

  /// Gets the name of the service stream for the connected VM service. Pre-v3.22
  /// this was a private API and named _Service and in v3.22 (July 2019) it was
  /// made public ("Service").
  Future<String> get serviceStreamName async =>
      (await isProtocolVersionSupported(
              supportedVersion: SemanticVersion(major: 3, minor: 22)))
          ? 'Service'
          : '_Service';

  @visibleForTesting
  Future<T> trackFuture<T>(String name, Future<T> future) {
    if (!trackFutures) {
      return future;
    }
    final trackedFuture = TrackedFuture(name, future);
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

class _CpuProfileTimelineTree {
  factory _CpuProfileTimelineTree.fromCpuSamples(CpuSamples cpuSamples) {
    final root = _CpuProfileTimelineTree._fromIndex(cpuSamples, kRootIndex);
    _CpuProfileTimelineTree current;
    // TODO(bkonyi): handle truncated?
    for (final sample in cpuSamples.samples) {
      current = root;
      // Build an inclusive trie.
      for (final index in sample.stack.reversed) {
        current = current._getChild(index);
      }
      _timelineTreeExpando[sample] = current;
    }
    return root;
  }

  _CpuProfileTimelineTree._fromIndex(this.samples, this.index);

  static final _timelineTreeExpando = Expando<_CpuProfileTimelineTree>();
  static const kRootIndex = -1;
  static const kNoFrameId = -1;
  final CpuSamples samples;
  final int index;
  int frameId = kNoFrameId;

  String get name => samples.functions[index].function.name;

  String get resolvedUrl => samples.functions[index].resolvedUrl;

  final children = <_CpuProfileTimelineTree>[];

  static _CpuProfileTimelineTree getTreeFromSample(CpuSample sample) =>
      _timelineTreeExpando[sample];

  _CpuProfileTimelineTree _getChild(int index) {
    final length = children.length;
    int i;
    for (i = 0; i < length; ++i) {
      final child = children[i];
      final childIndex = child.index;
      if (childIndex == index) {
        return child;
      }
      if (childIndex > index) {
        break;
      }
    }
    final child = _CpuProfileTimelineTree._fromIndex(samples, index);
    if (i < length) {
      children.insert(i, child);
    } else {
      children.add(child);
    }
    return child;
  }
}

/// Adds support for private VM RPCs that can only be used when VM developer
/// mode is enabled. Not for use outside of VM developer pages.
extension VmServicePrivate on VmServiceWrapper {
  /// Allows callers to invoke extension methods for private RPCs. This should
  /// only be set by [PreferencesController.toggleVmDeveloperMode] or tests.
  static bool enablePrivateRpcs = false;

  Future<T> _privateRpcInvoke<T>(
    String method, {
    @required T Function(Map<String, dynamic>) parser,
    String isolateId,
    Map args,
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
  Future<Success> collectAllGarbage() => _privateRpcInvoke(
        'collectAllGarbage',
        parser: Success.parse,
      );

  Future<PortList> getPorts(String isolateId) => _privateRpcInvoke(
        'getPorts',
        isolateId: isolateId,
        parser: PortList.parse,
      );
}
