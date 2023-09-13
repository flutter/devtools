// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:async/async.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:dap/dap.dart' as dap;
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vm_service/vm_service.dart';

import '../../service/vm_service_wrapper.dart';
import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/diagnostics/dap_object_node.dart';
import '../../shared/diagnostics/dart_object_node.dart';
import '../../shared/diagnostics/primitives/source_location.dart';
import '../../shared/diagnostics/tree_builder.dart';
import '../../shared/feature_flags.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/message_bus.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/routing.dart';
import 'codeview_controller.dart';
import 'debugger_model.dart';

// Make sure this a checked in with `mute: true`.
final _debugTimingLog = DebugTimingLogger('debugger', mute: true);

final _log = Logger('debugger_controller');

/// Responsible for managing the debug state of the app.
class DebuggerController extends DisposableController
    with AutoDisposeControllerMixin {
  // `initialSwitchToIsolate` can be set to false for tests to skip the logic
  // in `switchToIsolate`.
  DebuggerController({
    DevToolsRouterDelegate? routerDelegate,
    bool initialSwitchToIsolate = true,
  }) : _initialSwitchToIsolate = initialSwitchToIsolate {
    addAutoDisposeListener(serviceConnection.serviceManager.connectedState, () {
      if (serviceConnection.serviceManager.connectedState.value.connected) {
        _handleConnectionAvailable(serviceConnection.serviceManager.service!);
      }
    });
    if (routerDelegate != null) {
      codeViewController.subscribeToRouterEvents(routerDelegate);
    }
    addAutoDisposeListener(_selectedStackFrame, _updateCurrentFrame);
    addAutoDisposeListener(_stackFramesWithLocation, _updateCurrentFrame);

    if (serviceConnection.serviceManager.connectedState.value.connected) {
      _initialize();
    }
  }

  final codeViewController = CodeViewController();

  bool _firstDebuggerScreenLoaded = false;

  void _updateCurrentFrame() {
    serviceConnection.appState.setCurrentFrame(
      _selectedStackFrame.value?.frame ??
          _stackFramesWithLocation.value.safeFirst?.frame,
    );
  }

  /// Callback to be called when the debugger screen is first loaded.
  ///
  /// We delay calling this method until the debugger screen is first loaded
  /// for performance reasons. None of the code here needs to be called when
  /// DevTools first connects to an app, and doing so inhibits DevTools from
  /// connecting to low-end devices.
  Future<void> onFirstDebuggerScreenLoad() async {
    if (!_firstDebuggerScreenLoaded) {
      await codeViewController.maybeSetupProgramExplorer();
    }
  }

  /// Method to call after the vm service shuts down.
  void _onServiceShutdown() {
    _clearCaches();

    _hasTruncatedFrames.value = false;
    unawaited(_getStackOperation?.cancel());
    _getStackOperation = null;

    final appState = serviceConnection.appState;

    _resuming.value = false;
    _lastEvent = null;
    _stackFramesWithLocation.value = [];
    _selectedStackFrame.value = null;
    appState.setVariables([]);
    _selectedBreakpoint.value = null;
    _firstDebuggerScreenLoaded = false;
  }

  VmServiceWrapper? _lastService;

  void _handleConnectionAvailable(VmServiceWrapper service) {
    if (service == _lastService) return;
    _lastService = service;
    _onServiceShutdown();
    _initialize();
  }

  ValueListenable<IsolateRef?> get _isolate =>
      serviceConnection.serviceManager.isolateManager.selectedIsolate;

  void _initialize() {
    if (_initialSwitchToIsolate) {
      assert(_isolate.value != null);
      _switchToIsolate(_isolate.value);
    }

    addAutoDisposeListener(_isolate, () {
      _switchToIsolate(_isolate.value);
    });
    autoDisposeStreamSubscription(
      _service.onDebugEvent.listen(_handleDebugEvent),
    );
    autoDisposeStreamSubscription(
      _service.onIsolateEvent.listen(_handleIsolateEvent),
    );
  }

  final bool _initialSwitchToIsolate;

  VmServiceWrapper get _service {
    return serviceConnection.serviceManager.service!;
  }

  final _resuming = ValueNotifier<bool>(false);

  /// This indicates that we've requested a resume (or step) operation from the
  /// VM, but haven't yet received the 'resumed' isolate event.
  ValueListenable<bool> get resuming => _resuming;

  Event? _lastEvent;

  Event? get lastEvent => _lastEvent;

  final _stackFramesWithLocation =
      ValueNotifier<List<StackFrameAndSourcePosition>>([]);

  ValueListenable<List<StackFrameAndSourcePosition>>
      get stackFramesWithLocation => _stackFramesWithLocation;

  final _selectedStackFrame = ValueNotifier<StackFrameAndSourcePosition?>(null);

  ValueListenable<StackFrameAndSourcePosition?> get selectedStackFrame =>
      _selectedStackFrame;

  final _selectedBreakpoint = ValueNotifier<BreakpointAndSourcePosition?>(null);

  ValueListenable<BreakpointAndSourcePosition?> get selectedBreakpoint =>
      _selectedBreakpoint;

  final _exceptionPauseMode =
      ValueNotifier<String>(ExceptionPauseMode.kUnhandled);

  ValueListenable<String?> get exceptionPauseMode => _exceptionPauseMode;

  bool get isSystemIsolate => _isolate.value?.isSystemIsolate ?? false;

  String get _isolateRefId {
    final id = _isolate.value?.id;
    if (id == null) return '';
    return id;
  }

  void _switchToIsolate(IsolateRef? ref) async {
    // TODO(polina-c and jacob314): move this logic to appState
    // and modify to detect if app is paused from the isolate
    // https://github.com/flutter/devtools/pull/4993#discussion_r1060845351

    await _pause(false);

    _clearCaches();

    codeViewController.clearScriptHistory();

    if (ref == null) {
      await _getStackOperation?.cancel();
      await _populateFrameInfo([], truncated: false);
      return;
    }

    final isolate = await _service.getIsolate(_isolateRefId);
    if (isolate.id != _isolateRefId) {
      // Current request is obsolete.
      return;
    }

    if (isolate.pauseEvent != null &&
        isolate.pauseEvent!.kind != EventKind.kResume) {
      _lastEvent = isolate.pauseEvent;
      await _pause(true, pauseEvent: isolate.pauseEvent);
    }
    if (isolate.id != _isolateRefId) {
      // Current request is obsolete.
      return;
    }

    _exceptionPauseMode.value =
        isolate.exceptionPauseMode ?? ExceptionPauseMode.kUnhandled;

    if (isolate.id != _isolateRefId) {
      // Current request is obsolete.
      return;
    }
    await _populateScripts(isolate);
  }

  Future<Success> pause() => _service.pause(_isolateRefId);

  Future<Success> resume() {
    _debugTimingLog.log('resume()');
    _resuming.value = true;
    return _service.resume(_isolateRefId);
  }

  Future<Success> stepOver() {
    _debugTimingLog.log('stepOver()');
    _resuming.value = true;

    // Handle async suspensions; issue StepOption.kOverAsyncSuspension.
    final useAsyncStepping = _lastEvent?.atAsyncSuspension ?? false;
    return _service
        .resume(
          _isolateRefId,
          step: useAsyncStepping
              ? StepOption.kOverAsyncSuspension
              : StepOption.kOver,
        )
        .whenComplete(() => _debugTimingLog.log('stepOver() completed'));
  }

  Future<Success> stepIn() {
    _resuming.value = true;

    return _service.resume(_isolateRefId, step: StepOption.kInto);
  }

  Future<Success> stepOut() {
    _resuming.value = true;

    return _service.resume(_isolateRefId, step: StepOption.kOut);
  }

  Future<void> setIsolatePauseMode(String mode) async {
    await _service.setIsolatePauseMode(
      _isolateRefId,
      exceptionPauseMode: mode,
    );
    _exceptionPauseMode.value = mode;
  }

  /// Flutter starting with '--start-paused'. All subsequent isolates, after
  /// the first isolate, are in a pauseStart state too.  If _resuming, then
  /// resume any future isolate created with pause start.
  Future<Success> _resumeIsolatePauseStart(Event event) {
    assert(event.kind == EventKind.kPauseStart);
    assert(_resuming.value);

    final id = event.isolate!.id!;
    _debugTimingLog.log('resume() $id');
    return _service.resume(id);
  }

  void _handleDebugEvent(Event event) {
    _debugTimingLog.log('event: ${event.kind}');

    // We're resuming and another isolate has started in a paused state,
    // resume any pauseState isolates.
    if (_resuming.value &&
        event.isolate!.id != _isolateRefId &&
        event.kind == EventKind.kPauseStart) {
      unawaited(_resumeIsolatePauseStart(event));
    }

    if (event.isolate!.id != _isolateRefId) return;

    _lastEvent = event;

    switch (event.kind) {
      case EventKind.kResume:
        unawaited(_pause(false));
        break;
      case EventKind.kPauseStart:
      case EventKind.kPauseExit:
      case EventKind.kPauseBreakpoint:
      case EventKind.kPauseInterrupted:
      case EventKind.kPauseException:
      case EventKind.kPausePostRequest:
        // Any event we receive here indicates that any resume/step request has been
        // processed.
        _resuming.value = false;
        unawaited(_pause(true, pauseEvent: event));
        break;
    }
  }

  void _handleIsolateEvent(Event event) {
    final eventId = event.isolate?.id;
    if (eventId != _isolateRefId) return;
    switch (event.kind) {
      case EventKind.kIsolateReload:
        _updateAfterIsolateReload(event);
        break;
    }
  }

  void _updateAfterIsolateReload(Event reloadEvent) async {
    // Generally this has the value 'success'; we update our data in any case.
    // ignore: unused_local_variable
    final status = reloadEvent.status;

    final theIsolateRef = _isolate.value;
    if (theIsolateRef == null) return;
    // Refresh the list of scripts.
    final previousScriptRefs = scriptManager.sortedScripts.value;
    final currentScriptRefs =
        await scriptManager.retrieveAndSortScripts(theIsolateRef);
    final removedScripts =
        Set.of(previousScriptRefs).difference(Set.of(currentScriptRefs));
    final addedScripts =
        Set.of(currentScriptRefs).difference(Set.of(previousScriptRefs));

    // TODO(devoncarew): Show a message in the logging view.

    // Show a toast.
    final count = removedScripts.length + addedScripts.length;
    messageBus.addEvent(
      BusEvent(
        'toast',
        data: '${nf.format(count)} ${pluralize('script', count)} updated.',
      ),
    );

    // Redirect the current editor screen if necessary.
    if (removedScripts.contains(codeViewController.currentScriptRef.value)) {
      final uri = codeViewController.currentScriptRef.value!.uri;
      final newScriptRef =
          addedScripts.firstWhereOrNull((script) => script.uri == uri);

      if (newScriptRef != null) {
        // Display the script location.
        _populateScriptAndShowLocation(newScriptRef);
      }
    }
  }

  /// Jump to the given script.
  ///
  /// This method ensures that the source for the script is populated in our
  /// cache, in order to reduce flashing in the editor view.
  void _populateScriptAndShowLocation(ScriptRef scriptRef) {
    unawaited(
      scriptManager.getScript(scriptRef).then((script) {
        codeViewController.showScriptLocation(ScriptLocation(scriptRef));
      }),
    );
  }

  final _hasTruncatedFrames = ValueNotifier<bool>(false);

  CancelableOperation<_StackInfo>? _getStackOperation;

  Future<void> _pause(bool paused, {Event? pauseEvent}) async {
    // TODO(jacobr): unify pause support with
    // serviceManager.isolateManager.selectedIsolateState.isPaused.value;
    // listening for changes there instead of having separate logic.
    await _getStackOperation?.cancel();

    _debugTimingLog.log('_pause(running: ${!paused})');

    // Perform an early exit if we're not paused.
    if (!paused) {
      await _populateFrameInfo([], truncated: false);
      return;
    }

    // Collecting frames for Dart web applications can be slow. At the potential
    // cost of a flicker in the stack view, display only the top frame
    // initially.
    // TODO(elliette): Find a better solution for this. Currently, this means
    // we fetch all variable objects twice (once in _getFullStack and once in
    // in_createStackFrameWithLocation).
    if (await serviceConnection.serviceManager.connectedApp!.isDartWebApp) {
      final topFrame = pauseEvent?.topFrame;
      if (topFrame == null) {
        _log.warning(
          'Pause event has no frame. This likely indicates a DWDS bug.',
        );
        await _populateFrameInfo(
          [
            await _createStackFrameWithLocation(
              Frame(
                code: CodeRef(
                  name: 'No Dart frames found, likely paused in JS.',
                  kind: CodeKind.kTag,
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                ),
              ),
            ),
          ],
          truncated: true,
        );
        ga.select(gac.debugger, gac.pausedWithNoFrames);
        return;
      }
      await _populateFrameInfo(
        [
          await _createStackFrameWithLocation(topFrame),
        ],
        truncated: true,
      );
      unawaited(_getFullStack());
      return;
    }

    // We populate the first 12 frames; this ~roughly corresponds to the number
    // of visible stack frames.
    const initialFrameRequestCount = 12;

    _getStackOperation = CancelableOperation.fromFuture(
      _getStackInfo(
        limit: initialFrameRequestCount,
      ),
    );
    final stackInfo = await _getStackOperation!.value;
    await _populateFrameInfo(
      stackInfo.frames,
      truncated: stackInfo.truncated,
    );

    // In the background, populate the rest of the frames.
    if (stackInfo.truncated) {
      unawaited(_getFullStack());
    }
  }

  Future<_StackInfo> _getStackInfo({int? limit}) async {
    _debugTimingLog.log('getStack() with limit: $limit');
    final stack = await _service.getStack(_isolateRefId, limit: limit);
    _debugTimingLog
        .log('getStack() completed (frames: ${stack.frames!.length})');

    final frames = _framesForCallStack(
      stack.frames ?? [],
      asyncCausalFrames: stack.asyncCausalFrames ?? [],
      reportedException: _lastEvent?.exception,
    );

    return _StackInfo(
      await Future.wait(frames.map(_createStackFrameWithLocation)),
      stack.truncated ?? false,
    );
  }

  Future<void> _populateFrameInfo(
    List<StackFrameAndSourcePosition> frames, {
    required final bool truncated,
  }) async {
    _debugTimingLog.log('populated frame info');
    _stackFramesWithLocation.value = frames;
    _hasTruncatedFrames.value = truncated;
    if (frames.isEmpty) {
      await selectStackFrame(null);
    } else {
      await selectStackFrame(frames.first);
    }
  }

  Future<void> _getFullStack() async {
    await _getStackOperation?.cancel();
    _getStackOperation = CancelableOperation.fromFuture(_getStackInfo());
    final stackInfo = await _getStackOperation!.value;
    await _populateFrameInfo(stackInfo.frames, truncated: stackInfo.truncated);
  }

  void _clearCaches() {
    _lastEvent = null;
    breakpointManager.clearCache();
  }

  Future<void> _populateScripts(Isolate isolate) async {
    final theIsolateRef = _isolate.value;
    if (theIsolateRef == null) return;
    final scriptRefs =
        await scriptManager.retrieveAndSortScripts(theIsolateRef);

    // Update the selected script.
    final mainScriptRef = scriptRefs.firstWhereOrNull((ref) {
      return ref.uri == isolate.rootLib?.uri;
    });

    // Display the script location.
    if (mainScriptRef != null) {
      _populateScriptAndShowLocation(mainScriptRef);
    }
  }

  Future<StackFrameAndSourcePosition> _createStackFrameWithLocation(
    Frame frame,
  ) async {
    final scriptInfo = frame.location?.script;
    final tokenPos = frame.location?.tokenPos ?? -1;
    if (scriptInfo == null || tokenPos < 0) {
      return StackFrameAndSourcePosition(frame);
    }

    final script = await scriptManager.getScript(scriptInfo);
    final position = SourcePosition.calculatePosition(script, tokenPos);
    return StackFrameAndSourcePosition(frame, position: position);
  }

  Future<void> selectBreakpoint(BreakpointAndSourcePosition bp) async {
    _selectedBreakpoint.value = bp;

    final scriptRef = bp.scriptRef;
    if (scriptRef == null) return;

    if (bp.sourcePosition == null) {
      await codeViewController.showScriptLocation(ScriptLocation(scriptRef));
    } else {
      await codeViewController.showScriptLocation(
        ScriptLocation(scriptRef, location: bp.sourcePosition),
      );
    }
  }

  Future<void> selectStackFrame(StackFrameAndSourcePosition? frame) async {
    // Load the new script location:
    final scriptRef = frame?.scriptRef;
    final position = frame?.position;
    if (scriptRef != null && position != null) {
      await codeViewController.showScriptLocation(
        ScriptLocation(scriptRef, location: position),
      );
    }
    // Update the variables for the stack frame:
    if (FeatureFlags.dapDebugging) {
      serviceConnection.appState.setDapVariables(
        frame != null ? await _createDapVariablesForFrame(frame.frame) : [],
      );
    } else {
      serviceConnection.appState.setVariables(
        frame != null ? _createVariablesForFrame(frame.frame) : [],
      );
    }
    // Notify that the stack frame has been successfully selected:
    _selectedStackFrame.value = frame;
  }

  List<DartObjectNode> _createVariablesForFrame(Frame frame) {
    // vars can be null for async frames.
    if (frame.vars == null) {
      return [];
    }

    final variables = frame.vars!
        .map(
          (v) => DartObjectNode.create(
            v,
            _isolate.value,
          ),
        )
        .toList();
    // TODO(jacobr): would be nice to be able to remove this call to unawaited
    // but it would require a significant refactor.
    variables
      ..forEach((v) => unawaited(buildVariablesTree(v)))
      ..sort((a, b) => sortFieldsByName(a.name!, b.name!));
    return variables;
  }

  Future<List<DapObjectNode>> _createDapVariablesForFrame(Frame frame) async {
    // TODO(https://github.com/flutter/devtools/issues/6056): Use DAP for all
    // frames instead of translating between the current VM service frame and
    // the corresponding DAP frame.
    final dapFrame = await _fetchDapFrame(frame);
    final frameId = dapFrame?.id;
    if (frameId == null) return [];

    final dapObjectNodes = <DapObjectNode>[];

    final scopes = await _fetchDapScopes(frameId);
    for (final scope in scopes) {
      final variables = await _fetchDapVariables(scope.variablesReference);
      for (final variable in variables) {
        final node = DapObjectNode(variable: variable, service: _service);
        await node.fetchChildren();
        dapObjectNodes.add(node);
      }
    }

    return dapObjectNodes;
  }

  Future<dap.StackFrame?> _fetchDapFrame(Frame vmFrame) async {
    final isolateNumber = serviceConnection
        .serviceManager.isolateManager.selectedIsolate.value?.number;
    final frameIndex = vmFrame.index;
    if (isolateNumber == null || frameIndex == null) return null;

    final stackTraceResponse = await _service.dapStackTraceRequest(
      dap.StackTraceArguments(
        // The DAP thread ID is equivalent to the VM isolate number. See:
        // https://github.com/dart-lang/sdk/commit/95e6f1e1107ac3f494ca3dc97ffd12cf261313a9
        threadId: int.parse(isolateNumber),
        startFrame: frameIndex,
        levels: 1, // The number of frames to return.
      ),
    );
    return stackTraceResponse?.stackFrames.first;
  }

  Future<List<dap.Scope>> _fetchDapScopes(int frameId) async {
    final scopesResponse = await _service.dapScopesRequest(
      dap.ScopesArguments(
        frameId: frameId,
      ),
    );
    return scopesResponse?.scopes ?? [];
  }

  Future<List<dap.Variable>> _fetchDapVariables(int variablesReference) async {
    final variablesResponse = await _service.dapVariablesRequest(
      dap.VariablesArguments(
        variablesReference: variablesReference,
      ),
    );
    return variablesResponse?.variables ?? [];
  }

  List<Frame> _framesForCallStack(
    List<Frame> stackFrames, {
    List<Frame>? asyncCausalFrames,
    InstanceRef? reportedException,
  }) {
    // Prefer asyncCausalFrames if they exist.
    List<Frame> frames =
        asyncCausalFrames != null && asyncCausalFrames.isNotEmpty
            ? asyncCausalFrames
            : stackFrames;

    // Include any reported exception as a variable in the first frame.
    if (reportedException != null && frames.isNotEmpty) {
      final frame = frames.first;

      final newFrame = Frame(
        index: frame.index,
        function: frame.function,
        code: frame.code,
        location: frame.location,
        kind: frame.kind,
      );

      newFrame.vars = [
        BoundVariable(
          name: '<exception>',
          value: reportedException,
        ),
        ...frame.vars ?? [],
      ];

      frames = [newFrame, ...frames.sublist(1)];
    }

    return frames;
  }
}

class _StackInfo {
  _StackInfo(this.frames, this.truncated);

  final List<StackFrameAndSourcePosition> frames;
  final bool truncated;
}
