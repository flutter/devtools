// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Stack;
import 'package:pedantic/pedantic.dart';
import 'package:vm_service/vm_service.dart';

import '../auto_dispose.dart';
import '../core/message_bus.dart';
import '../globals.dart';
import '../utils.dart';
import 'debugger_model.dart';

// TODO(devoncarew): Add some delayed resume value notifiers (to be used to
// help debounce stepping operations).

// Make sure this a checked in with `mute: true`.
final _log = DebugTimingLogger('debugger', mute: true);

/// Responsible for managing the debug state of the app.
class DebuggerController extends DisposableController
    with AutoDisposeControllerMixin {
  // `initialSwitchToIsolate` can be set to false for tests to skip the logic
  // in `switchToIsolate`.
  DebuggerController({bool initialSwitchToIsolate = true}) {
    if (initialSwitchToIsolate) {
      switchToIsolate(serviceManager.isolateManager.selectedIsolate);
    }

    autoDispose(serviceManager.isolateManager.onSelectedIsolateChanged
        .listen(switchToIsolate));
    autoDispose(_service.onDebugEvent.listen(_handleDebugEvent));
    autoDispose(_service.onIsolateEvent.listen(_handleIsolateEvent));
    autoDispose(_service.onStdoutEvent.listen(_handleStdoutEvent));
    autoDispose(_service.onStderrEvent.listen(_handleStderrEvent));

    _scriptHistoryListener = () {
      _showScriptLocation(ScriptLocation(scriptsHistory.currentScript));
    };
    scriptsHistory.addListener(_scriptHistoryListener);
  }

  VmService get _service => serviceManager.service;

  final ScriptCache _scriptCache = ScriptCache();

  final ScriptsHistory scriptsHistory = ScriptsHistory();
  VoidCallback _scriptHistoryListener;

  final _isPaused = ValueNotifier<bool>(false);

  ValueListenable<bool> get isPaused => _isPaused;

  final _resuming = ValueNotifier<bool>(false);

  /// This indicates that we've requested a resume (or step) operation from the
  /// VM, but haven't yet received the 'resumed' isolate event.
  ValueListenable<bool> get resuming => _resuming;

  final _hasFrames = ValueNotifier<bool>(false);

  ValueNotifier get hasFrames => _hasFrames;

  Event _lastEvent;

  Event get lastEvent => _lastEvent;

  final _currentScriptRef = ValueNotifier<ScriptRef>(null);

  ValueListenable<ScriptRef> get currentScriptRef => _currentScriptRef;

  final _scriptLocation = ValueNotifier<ScriptLocation>(null);

  ValueListenable<ScriptLocation> get scriptLocation => _scriptLocation;

  /// Jump to the given ScriptRef and optional SourcePosition.
  void showScriptLocation(ScriptLocation scriptLocation) {
    _showScriptLocation(scriptLocation);

    // Update the scripts history (and make sure we don't react to the
    // subsequent event).
    scriptsHistory.removeListener(_scriptHistoryListener);
    scriptsHistory.pushEntry(scriptLocation.scriptRef);
    scriptsHistory.addListener(_scriptHistoryListener);
  }

  /// Show the given script location (without updating the script navigation
  /// history).
  void _showScriptLocation(ScriptLocation scriptLocation) {
    _currentScriptRef.value = scriptLocation?.scriptRef;
    _scriptLocation.value = scriptLocation;
  }

  // A cached map of uris to ScriptRefs.
  final Map<String, ScriptRef> _uriToScriptMap = {};

  final _stackFramesWithLocation =
      ValueNotifier<List<StackFrameAndSourcePosition>>([]);

  ValueListenable<List<StackFrameAndSourcePosition>>
      get stackFramesWithLocation => _stackFramesWithLocation;

  final _selectedStackFrame = ValueNotifier<StackFrameAndSourcePosition>(null);

  ValueListenable<StackFrameAndSourcePosition> get selectedStackFrame =>
      _selectedStackFrame;

  final _variables = ValueNotifier<List<Variable>>([]);

  ValueListenable<List<Variable>> get variables => _variables;

  final _sortedScripts = ValueNotifier<List<ScriptRef>>([]);

  /// Return the sorted list of ScriptRefs active in the current isolate.
  ValueListenable<List<ScriptRef>> get sortedScripts => _sortedScripts;

  final _breakpoints = ValueNotifier<List<Breakpoint>>([]);

  ValueListenable<List<Breakpoint>> get breakpoints => _breakpoints;

  final _breakpointsWithLocation =
      ValueNotifier<List<BreakpointAndSourcePosition>>([]);

  ValueListenable<List<BreakpointAndSourcePosition>>
      get breakpointsWithLocation => _breakpointsWithLocation;

  final _selectedBreakpoint = ValueNotifier<BreakpointAndSourcePosition>(null);

  ValueListenable<BreakpointAndSourcePosition> get selectedBreakpoint =>
      _selectedBreakpoint;

  final _exceptionPauseMode =
      ValueNotifier<String>(ExceptionPauseMode.kUnhandled);

  ValueListenable<String> get exceptionPauseMode => _exceptionPauseMode;

  final _librariesVisible = ValueNotifier(false);

  ValueListenable<bool> get librariesVisible => _librariesVisible;

  /// Make the 'Libraries' view on the right-hand side of the screen visible or
  /// hidden.
  void toggleLibrariesVisible() {
    _librariesVisible.value = !_librariesVisible.value;
  }

  final _stdio = ValueNotifier<List<String>>([]);
  bool _stdioTrailingNewline = false;

  /// Return the stdout and stderr emitted from the application.
  ///
  /// Note that this output might be truncated after significant output.
  ValueListenable<List<String>> get stdio => _stdio;

  IsolateRef isolateRef;

  /// Clears the contents of stdio.
  void clearStdio() {
    _stdio.value = [];
  }

  /// Append to the stdout / stderr buffer.
  void appendStdio(String text) {
    const int kMaxLogItemsLowerBound = 5000;
    const int kMaxLogItemsUpperBound = 5500;

    // Parse out the new lines and append to the end of the existing lines.
    var lines = _stdio.value.toList();
    final newLines = text.split('\n');

    if (lines.isNotEmpty && !_stdioTrailingNewline) {
      lines[lines.length - 1] = '${lines[lines.length - 1]}${newLines.first}';
      if (newLines.length > 1) {
        lines.addAll(newLines.sublist(1));
      }
    } else {
      lines.addAll(newLines);
    }

    _stdioTrailingNewline = text.endsWith('\n');

    // Don't report trailing blank lines.
    if (lines.isNotEmpty && lines.last.isEmpty) {
      lines = lines.sublist(0, lines.length - 1);
    }

    // For performance reasons, we drop older lines in batches, so the lines
    // will grow to kMaxLogItemsUpperBound then truncate to
    // kMaxLogItemsLowerBound.
    if (lines.length > kMaxLogItemsUpperBound) {
      lines = lines.sublist(lines.length - kMaxLogItemsLowerBound);
    }

    _stdio.value = lines;
  }

  final EvalHistory evalHistory = EvalHistory();

  void switchToIsolate(IsolateRef ref) async {
    isolateRef = ref;

    _isPaused.value = false;
    await _pause(false);

    _clearCaches();

    if (ref == null) {
      _breakpoints.value = [];
      _breakpointsWithLocation.value = [];
      _stackFramesWithLocation.value = [];
      return;
    }

    final isolate = await _service.getIsolate(isolateRef.id);

    if (isolate.pauseEvent != null &&
        isolate.pauseEvent.kind != EventKind.kResume) {
      _lastEvent = isolate.pauseEvent;
      await _pause(true, pauseEvent: isolate.pauseEvent);
    }

    _breakpoints.value = isolate.breakpoints;

    // Build _breakpointsWithLocation from _breakpoints.
    if (_breakpoints.value != null) {
      // ignore: unawaited_futures
      Future.wait(_breakpoints.value.map(_createBreakpointWithLocation))
          .then((list) {
        _breakpointsWithLocation.value = list.toList()..sort();
      });
    }

    _exceptionPauseMode.value = isolate.exceptionPauseMode;

    await _populateScripts(isolate);
  }

  Future<Success> pause() => _service.pause(isolateRef.id);

  Future<Success> resume() {
    _log.log('resume()');
    _resuming.value = true;
    return _service.resume(isolateRef.id);
  }

  Future<Success> stepOver() {
    _log.log('stepOver()');
    _resuming.value = true;

    // Handle async suspensions; issue StepOption.kOverAsyncSuspension.
    final useAsyncStepping = _lastEvent?.atAsyncSuspension ?? false;
    return _service
        .resume(
          isolateRef.id,
          step: useAsyncStepping
              ? StepOption.kOverAsyncSuspension
              : StepOption.kOver,
        )
        .whenComplete(() => _log.log('stepOver() completed'));
  }

  Future<Success> stepIn() {
    _resuming.value = true;

    return _service.resume(isolateRef.id, step: StepOption.kInto);
  }

  Future<Success> stepOut() {
    _resuming.value = true;

    return _service.resume(isolateRef.id, step: StepOption.kOut);
  }

  /// Evaluate the given expression in the context of the currently selected
  /// stack frame, or the top frame if there is no current selection.
  ///
  /// This will fail if the application is not currently paused.
  Future<Response> evalAtCurrentFrame(String expression) async {
    if (!isPaused.value) {
      return Future.error(
        RPCError.withDetails(
            'evaluateInFrame', RPCError.kInvalidParams, 'Isolate not paused'),
      );
    }

    if (stackFramesWithLocation.value.isEmpty) {
      return Future.error(
        RPCError.withDetails(
            'evaluateInFrame', RPCError.kInvalidParams, 'No frames available'),
      );
    }

    final frame = selectedStackFrame.value?.frame ??
        stackFramesWithLocation.value.first.frame;

    return _service.evaluateInFrame(
      isolateRef.id,
      frame.index,
      expression,
      disableBreakpoints: true,
    );
  }

  /// Call `toString()` on the given instance and return the result.
  Future<Response> invokeToString(InstanceRef instance) {
    return _service.invoke(
      isolateRef.id,
      instance.id,
      'toString',
      <String>[],
      disableBreakpoints: true,
    );
  }

  /// Retrieves the full string value of a [stringRef].
  Future<String> retrieveFullStringValue(
    InstanceRef stringRef, {
    String onUnavailable(String truncatedValue),
  }) async {
    return serviceManager.service.retrieveFullStringValue(
      isolateRef.id,
      stringRef,
      onUnavailable: onUnavailable,
    );
  }

  Future<void> clearBreakpoints() async {
    final breakpoints = _breakpoints.value.toList();
    await Future.forEach(breakpoints, (Breakpoint breakpoint) {
      return removeBreakpoint(breakpoint);
    });
  }

  Future<Breakpoint> addBreakpoint(String scriptId, int line) =>
      _service.addBreakpoint(isolateRef.id, scriptId, line);

  Future<void> removeBreakpoint(Breakpoint breakpoint) =>
      _service.removeBreakpoint(isolateRef.id, breakpoint.id);

  Future<void> setExceptionPauseMode(String mode) async {
    await _service.setExceptionPauseMode(isolateRef.id, mode);
    _exceptionPauseMode.value = mode;
  }

  /// Flutter starting with '--start-paused'. All subsequent isolates, after
  /// the first isolate, are in a pauseStart state too.  If _resuming, then
  /// resume any future isolate created with pause start.
  Future<Success> _resumeIsolatePauseStart(Event event) {
    assert(event.kind == EventKind.kPauseStart);
    assert(_resuming.value);

    final id = event.isolate.id;
    _log.log('resume() $id');
    return _service.resume(id);
  }

  void _handleDebugEvent(Event event) {
    _log.log('event: ${event.kind}');

    // We're resuming and another isolate has started in a paused state,
    // resume any pauseState isolates.
    if (_resuming.value &&
        event.isolate.id != isolateRef?.id &&
        event.kind == EventKind.kPauseStart) {
      _resumeIsolatePauseStart(event);
    }

    if (event.isolate.id != isolateRef?.id) return;

    _hasFrames.value = event.topFrame != null;
    _lastEvent = event;

    switch (event.kind) {
      case EventKind.kResume:
        _pause(false);
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
        _pause(true, pauseEvent: event);
        break;
      // TODO(djshuckerow): switch the _breakpoints notifier to a 'ListNotifier'
      // that knows how to notify when performing a list edit operation.
      case EventKind.kBreakpointAdded:
        _breakpoints.value = [..._breakpoints.value, event.breakpoint];

        // ignore: unawaited_futures
        _createBreakpointWithLocation(event.breakpoint).then((bp) {
          final list = [
            ..._breakpointsWithLocation.value,
            bp,
          ]..sort();

          _breakpointsWithLocation.value = list;
        });

        break;
      case EventKind.kBreakpointResolved:
        _breakpoints.value = [
          for (var b in _breakpoints.value) if (b != event.breakpoint) b,
          event.breakpoint
        ];

        // ignore: unawaited_futures
        _createBreakpointWithLocation(event.breakpoint).then((bp) {
          final list = _breakpointsWithLocation.value.toList();
          // Remote the bp with the older, unresolved information from the list.
          list.removeWhere((breakpoint) => bp.breakpoint.id == bp.id);
          // Add the bp with the newer, resolved information.
          list.add(bp);
          list.sort();
          _breakpointsWithLocation.value = list;
        });

        break;
      case EventKind.kBreakpointRemoved:
        final breakpoint = event.breakpoint;

        // Update _selectedBreakpoint if necessary.
        if (_selectedBreakpoint.value?.breakpoint == breakpoint) {
          _selectedBreakpoint.value = null;
        }

        _breakpoints.value = [
          for (var b in _breakpoints.value) if (b != breakpoint) b
        ];

        _breakpointsWithLocation.value = [
          for (var b in _breakpointsWithLocation.value)
            if (b.breakpoint != breakpoint) b
        ];

        break;
    }
  }

  void _handleIsolateEvent(Event event) {
    if (event.isolate.id != isolateRef?.id) return;

    switch (event.kind) {
      case EventKind.kIsolateReload:
        _updateAfterIsolateReload(event);
        break;
    }
  }

  void _handleStdoutEvent(Event event) {
    final String text = decodeBase64(event.bytes);
    appendStdio(text);
  }

  void _handleStderrEvent(Event event) {
    final String text = decodeBase64(event.bytes);
    // TODO(devoncarew): Change to reporting stdio along with information about
    // whether the event was stdout or stderr.
    appendStdio(text);
  }

  Future<List<ScriptRef>> _retrieveAndSortScripts(IsolateRef ref) async {
    final scriptList = await _service.getScripts(isolateRef.id);
    // We filter out non-unique ScriptRefs here (dart-lang/sdk/issues/41661).
    final scriptRefs = Set.of(scriptList.scripts).toList();
    scriptRefs.sort((a, b) {
      // We sort uppercase so that items like dart:foo sort before items like
      // dart:_foo.
      return a.uri.toUpperCase().compareTo(b.uri.toUpperCase());
    });
    return scriptRefs;
  }

  void _updateAfterIsolateReload(Event reloadEvent) async {
    // Generally this has the value 'success'; we update our data in any case.
    // ignore: unused_local_variable
    final status = reloadEvent.status;

    // Refresh the list of scripts.
    final scriptRefs = await _retrieveAndSortScripts(isolateRef);
    for (var scriptRef in scriptRefs) {
      _uriToScriptMap[scriptRef.uri] = scriptRef;
    }

    final removedScripts =
        Set.of(_sortedScripts.value).difference(Set.of(scriptRefs));
    final addedScripts =
        Set.of(scriptRefs).difference(Set.of(_sortedScripts.value));

    _sortedScripts.value = scriptRefs;

    // TODO(devoncarew): Show a message in the logging view.

    // Show a toast.
    final count = removedScripts.length + addedScripts.length;
    messageBus.addEvent(BusEvent('toast',
        data: '${nf.format(count)} ${pluralize('script', count)} updated.'));

    // Update breakpoints.
    _updateBreakpointsAfterReload(removedScripts, addedScripts);

    // Redirect the current editor screen if necessary.
    if (removedScripts.contains(currentScriptRef.value)) {
      final uri = currentScriptRef.value.uri;
      final newScriptRef = addedScripts
          .firstWhere((script) => script.uri == uri, orElse: () => null);

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
    getScript(scriptRef).then((script) {
      showScriptLocation(ScriptLocation(scriptRef));
    });
  }

  void _updateBreakpointsAfterReload(
    Set<ScriptRef> removedScripts,
    Set<ScriptRef> addedScripts,
  ) {
    // TODO(devoncarew): We need to coordinate this with other debugger clients
    // as well as pause before re-setting the breakpoints.

    final breakpointsToRemove = <BreakpointAndSourcePosition>[];

    // Find all breakpoints set in files where we have newer versions of those
    // files.
    for (final scriptRef in removedScripts) {
      for (final bp in breakpointsWithLocation.value) {
        if (bp.scriptRef == scriptRef) {
          breakpointsToRemove.add(bp);
        }
      }
    }

    // Remove the breakpoints.
    for (final bp in breakpointsToRemove) {
      removeBreakpoint(bp.breakpoint);
    }

    // Add them back to the newer versions of those scripts.
    for (final scriptRef in addedScripts) {
      for (final bp in breakpointsToRemove) {
        if (scriptRef.uri == bp.scriptUri) {
          addBreakpoint(scriptRef.id, bp.line);
        }
      }
    }
  }

  Future<void> _pause(bool paused, {Event pauseEvent}) async {
    _isPaused.value = paused;

    _log.log('_pause(running: ${!paused})');

    // Perform an early exit if we're not paused.
    if (!paused) {
      _stackFramesWithLocation.value = [];
      selectStackFrame(null);
      return;
    }

    // First, notify based on the single 'pauseEvent.topFrame' frame.
    if (pauseEvent?.topFrame != null) {
      final tempFrames = _framesForCallStack(
        [pauseEvent.topFrame],
        reportedException: pauseEvent?.exception,
      );
      _stackFramesWithLocation.value = [
        await _createStackFrameWithLocation(tempFrames.first),
      ];
      _log.log('created first frame');
      selectStackFrame(_stackFramesWithLocation.value.first);
    }

    // Then, issue an asynchronous request to populate the frame information.
    _log.log('getStack()');
    final stack = await _service.getStack(isolateRef.id);
    _log.log('getStack() completed (frames: ${stack.frames.length})');
    final frames = _framesForCallStack(
      stack.frames,
      asyncCausalFrames: stack.asyncCausalFrames,
      reportedException: pauseEvent?.exception,
    );

    _stackFramesWithLocation.value =
        await Future.wait(frames.map(_createStackFrameWithLocation));
    _log.log('populated frame info');
    if (_stackFramesWithLocation.value.isEmpty) {
      selectStackFrame(null);
    } else {
      selectStackFrame(_stackFramesWithLocation.value.first);
    }
  }

  void _clearCaches() {
    _scriptCache.clear();
    _lastEvent = null;
    _breakPositionsMap.clear();
    _stdio.value = [];
    _uriToScriptMap.clear();
  }

  /// Get the populated [Obj] object, given an [ObjRef].
  ///
  /// The return value can be one of [Obj] or [Sentinel].
  Future<Obj> getObject(ObjRef objRef) {
    return _service.getObject(isolateRef.id, objRef.id);
  }

  /// Return a cached [Script] for the given [ScriptRef], returning null
  /// if there is no cached [Script].
  Script getScriptCached(ScriptRef scriptRef) {
    return _scriptCache.getScriptCached(scriptRef);
  }

  /// Retrieve the [Script] for the given [ScriptRef].
  ///
  /// This caches the script lookup for future invocations.
  Future<Script> getScript(ScriptRef scriptRef) {
    return _scriptCache.getScript(_service, isolateRef, scriptRef);
  }

  /// Return the [ScriptRef] at the given [uri].
  ScriptRef scriptRefForUri(String uri) {
    return _uriToScriptMap[uri];
  }

  Future<void> _populateScripts(Isolate isolate) async {
    final scriptRefs = await _retrieveAndSortScripts(isolateRef);
    _sortedScripts.value = scriptRefs;

    for (var scriptRef in scriptRefs) {
      _uriToScriptMap[scriptRef.uri] = scriptRef;
    }

    // Update the selected script.
    final mainScriptRef = scriptRefs.firstWhere((ref) {
      return ref.uri == isolate.rootLib.uri;
    }, orElse: () => null);

    // Display the script location.
    _populateScriptAndShowLocation(mainScriptRef);
  }

  SourcePosition calculatePosition(Script script, int tokenPos) {
    final List<List<int>> table = script.tokenPosTable;
    if (table == null) {
      return null;
    }

    return SourcePosition(
      line: script.getLineNumberFromTokenPos(tokenPos),
      column: script.getColumnNumberFromTokenPos(tokenPos),
      tokenPos: tokenPos,
    );
  }

  Future<BreakpointAndSourcePosition> _createBreakpointWithLocation(
      Breakpoint breakpoint) async {
    if (breakpoint.resolved) {
      final bp = BreakpointAndSourcePosition.create(breakpoint);
      return getScript(bp.scriptRef).then((Script script) {
        final pos = calculatePosition(script, bp.tokenPos);
        return BreakpointAndSourcePosition.create(breakpoint, pos);
      });
    } else {
      return BreakpointAndSourcePosition.create(breakpoint);
    }
  }

  Future<StackFrameAndSourcePosition> _createStackFrameWithLocation(
    Frame frame,
  ) async {
    final location = frame.location;
    if (location == null) {
      return StackFrameAndSourcePosition(frame);
    }

    final script = await getScript(location.script);
    final position = calculatePosition(script, location.tokenPos);
    return StackFrameAndSourcePosition(frame, position: position);
  }

  void selectBreakpoint(BreakpointAndSourcePosition bp) {
    _selectedBreakpoint.value = bp;

    if (bp.sourcePosition == null) {
      showScriptLocation(ScriptLocation(bp.scriptRef));
    } else {
      showScriptLocation(
          ScriptLocation(bp.scriptRef, location: bp.sourcePosition));
    }
  }

  void selectStackFrame(StackFrameAndSourcePosition frame) {
    _selectedStackFrame.value = frame;

    if (frame != null) {
      _variables.value = _createVariablesForFrame(frame.frame);
    } else {
      _variables.value = [];
    }

    if (frame?.scriptRef != null) {
      showScriptLocation(
          ScriptLocation(frame.scriptRef, location: frame.position));
    }
  }

  List<Variable> _createVariablesForFrame(Frame frame) {
    // vars can be null for async frames.
    if (frame.vars == null) {
      return [];
    }

    final variables = frame.vars.map((v) => Variable.create(v)).toList();
    variables.forEach(buildVariablesTree);
    return variables;
  }

  /// Builds the tree representation for a [Variable] object by querying data,
  /// creating child Variable objects, and assigning parent-child relationships.
  ///
  /// We call this method as we expand variables in the variable tree, because
  /// building the tree for all variable data at once is very expensive.
  Future<void> buildVariablesTree(Variable variable) async {
    if (!variable.isExpandable ||
        variable.treeInitialized ||
        variable.boundVar.value is! InstanceRef) return;

    final InstanceRef instanceRef = variable.boundVar.value;
    try {
      final dynamic result = await getObject(instanceRef);
      if (result is Instance) {
        if (result.associations != null) {
          variable.addAllChildren(_createVariablesForAssociations(result));
        } else if (result.elements != null) {
          variable.addAllChildren(_createVariablesForElements(result));
        } else if (result.bytes != null) {
          variable.addAllChildren(_createVariablesForBytes(result));
          // Check fields last, as all instanceRefs may have a non-null fields
          // with no entries.
        } else if (result.fields != null) {
          variable.addAllChildren(_createVariablesForFields(result));
        }
      }
    } on SentinelException {
      // Fail gracefully if calling `getObject` throws a SentinelException.
    }
    variable.treeInitialized = true;
  }

  List<Variable> _createVariablesForAssociations(Instance instance) {
    final variables = <Variable>[];
    for (var i = 0; i < instance.associations.length; i++) {
      final association = instance.associations[i];
      if (association.key is! InstanceRef) {
        continue;
      }
      final key = BoundVariable(
        name: '[key]',
        value: association.key,
        scopeStartTokenPos: null,
        scopeEndTokenPos: null,
        declarationTokenPos: null,
      );
      final value = BoundVariable(
        name: '[value]',
        value: association.value,
        scopeStartTokenPos: null,
        scopeEndTokenPos: null,
        declarationTokenPos: null,
      );
      final variable = Variable.create(
        BoundVariable(
          name: '[Entry $i]',
          value: '',
          scopeStartTokenPos: null,
          scopeEndTokenPos: null,
          declarationTokenPos: null,
        ),
      );
      variable.addChild(Variable.create(key));
      variable.addChild(Variable.create(value));
      variables.add(variable);
    }
    return variables;
  }

  /// Decodes the bytes into the correctly sized values based on
  /// [Instance.kind], falling back to raw bytes if a type is not
  /// matched.
  ///
  /// This method does not currently support [Uint64List] or
  /// [Int64List].
  List<Variable> _createVariablesForBytes(Instance instance) {
    final bytes = base64.decode(instance.bytes);
    final boundVariables = <BoundVariable>[];
    List<dynamic> result;
    switch (instance.kind) {
      case InstanceKind.kUint8ClampedList:
      case InstanceKind.kUint8List:
        result = bytes;
        break;
      case InstanceKind.kUint16List:
        result = Uint16List.view(bytes.buffer);
        break;
      case InstanceKind.kUint32List:
        result = Uint32List.view(bytes.buffer);
        break;
      case InstanceKind.kUint64List:
        // TODO: https://github.com/flutter/devtools/issues/2159
        if (kIsWeb) {
          return <Variable>[];
        }
        result = Uint64List.view(bytes.buffer);
        break;
      case InstanceKind.kInt8List:
        result = Int8List.view(bytes.buffer);
        break;
      case InstanceKind.kInt16List:
        result = Int16List.view(bytes.buffer);
        break;
      case InstanceKind.kInt32List:
        result = Int32List.view(bytes.buffer);
        break;
      case InstanceKind.kInt64List:
        // TODO: https://github.com/flutter/devtools/issues/2159
        if (kIsWeb) {
          return <Variable>[];
        }
        result = Int64List.view(bytes.buffer);
        break;
      case InstanceKind.kFloat32List:
        result = Float32List.view(bytes.buffer);
        break;
      case InstanceKind.kFloat64List:
        result = Float64List.view(bytes.buffer);
        break;
      case InstanceKind.kInt32x4List:
        result = Int32x4List.view(bytes.buffer);
        break;
      case InstanceKind.kFloat32x4List:
        result = Float32x4List.view(bytes.buffer);
        break;
      case InstanceKind.kFloat64x2List:
        result = Float64x2List.view(bytes.buffer);
        break;
      default:
        result = bytes;
    }

    for (int i = 0; i < result.length; i++) {
      boundVariables.add(BoundVariable(
        name: '[$i]',
        value: result[i],
        scopeStartTokenPos: null,
        scopeEndTokenPos: null,
        declarationTokenPos: null,
      ));
    }
    return boundVariables.map((bv) => Variable.create(bv)).toList();
  }

  List<Variable> _createVariablesForElements(Instance instance) {
    final boundVariables = <BoundVariable>[];
    for (int i = 0; i < instance.elements.length; i++) {
      boundVariables.add(BoundVariable(
        name: '[$i]',
        value: instance.elements[i],
        scopeStartTokenPos: null,
        scopeEndTokenPos: null,
        declarationTokenPos: null,
      ));
    }
    return boundVariables.map((bv) => Variable.create(bv)).toList();
  }

  List<Variable> _createVariablesForFields(Instance instance) {
    final boundVariables = instance.fields.map((field) {
      return BoundVariable(
        name: field.decl.name,
        value: field.value,
        scopeStartTokenPos: null,
        scopeEndTokenPos: null,
        declarationTokenPos: null,
      );
    });
    return boundVariables.map((bv) => Variable.create(bv)).toList();
  }

  List<Frame> _framesForCallStack(
    List<Frame> stackFrames, {
    List<Frame> asyncCausalFrames,
    InstanceRef reportedException,
  }) {
    // Prefer asyncCausalFrames if they exist.
    List<Frame> frames = asyncCausalFrames ?? stackFrames;

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
          scopeStartTokenPos: null,
          scopeEndTokenPos: null,
          declarationTokenPos: null,
        ),
        ...frame.vars ?? []
      ];

      frames = [newFrame, ...frames.sublist(1)];
    }

    return frames;
  }

  final Map<String, List<SourcePosition>> _breakPositionsMap = {};

  /// Return the list of valid positions for breakpoints for a given script.
  Future<List<SourcePosition>> getBreakablePositions(Script script) async {
    if (!_breakPositionsMap.containsKey(script.id)) {
      _breakPositionsMap[script.id] = await _getBreakablePositions(script);
    }

    return _breakPositionsMap[script.id];
  }

  Future<List<SourcePosition>> _getBreakablePositions(Script script) async {
    final report = await _service.getSourceReport(
      isolateRef.id,
      [SourceReportKind.kPossibleBreakpoints],
      scriptId: script.id,
      forceCompile: true,
    );

    final positions = <SourcePosition>[];

    for (SourceReportRange range in report.ranges) {
      if (range.possibleBreakpoints != null) {
        for (int tokenPos in range.possibleBreakpoints) {
          positions.add(calculatePosition(script, tokenPos));
        }
      }
    }

    return positions;
  }
}

class ScriptCache {
  ScriptCache();

  Map<String, Script> _scripts = {};
  final Map<String, Future<Script>> _inProgress = {};

  /// Return a cached [Script] for the given [ScriptRef], returning null
  /// if there is no cached [Script].
  Script getScriptCached(ScriptRef scriptRef) {
    return _scripts[scriptRef?.id];
  }

  /// Retrieve the [Script] for the given [ScriptRef].
  ///
  /// This caches the script lookup for future invocations.
  Future<Script> getScript(
      VmService vmService, IsolateRef isolateRef, ScriptRef scriptRef) {
    if (_scripts.containsKey(scriptRef.id)) {
      return Future.value(_scripts[scriptRef.id]);
    }

    if (_inProgress.containsKey(scriptRef.id)) {
      return _inProgress[scriptRef.id];
    }

    // We make a copy here as the future could complete after a clear()
    // operation is performed.
    final scripts = _scripts;

    final Future<Script> scriptFuture = vmService
        .getObject(isolateRef.id, scriptRef.id)
        .then((obj) => obj as Script);
    _inProgress[scriptRef.id] = scriptFuture;

    unawaited(scriptFuture.then((script) {
      scripts[scriptRef.id] = script;
    }));

    return scriptFuture;
  }

  void clear() {
    _scripts = {};
    _inProgress.clear();
  }
}

/// Maintains the navigation history of the debugger's code area - which files
/// were opened, whether it's possible to navigate forwards and backwards in the
/// history, ...
class ScriptsHistory extends ChangeNotifier
    implements ValueListenable<ScriptsHistory> {
  // TODO(devoncarew): This class should also record and restore scroll
  // positions.

  ScriptsHistory();

  final _history = <ScriptRef>[];
  int _historyIndex = -1;

  final _openedScripts = <ScriptRef>{};

  bool get hasPrevious {
    return _history.isNotEmpty && _historyIndex > 0;
  }

  bool get hasNext {
    return _history.isNotEmpty && _historyIndex < _history.length - 1;
  }

  bool get hasScripts => _openedScripts.isNotEmpty;

  ScriptRef moveForward() {
    if (!hasNext) throw StateError('no next history item');

    _historyIndex++;

    notifyListeners();

    return currentScript;
  }

  ScriptRef moveBack() {
    if (!hasPrevious) throw StateError('no previous history item');

    _historyIndex--;

    notifyListeners();

    return currentScript;
  }

  ScriptRef get currentScript {
    return _history.isEmpty ? null : _history[_historyIndex];
  }

  void pushEntry(ScriptRef ref) {
    if (ref == currentScript) return;

    while (hasNext) {
      _history.removeLast();
    }

    _openedScripts.remove(ref);
    _openedScripts.add(ref);

    _history.add(ref);
    _historyIndex++;

    notifyListeners();
  }

  @override
  ScriptsHistory get value => this;

  Iterable<ScriptRef> get openedScripts => _openedScripts.toList().reversed;
}

/// Store and manipulate the expression evaluation history.
class EvalHistory {
  var _historyPosition = -1;

  /// Get the expression evaluation history.
  List<String> get evalHistory => _evalHistory.toList();

  final _evalHistory = <String>[];

  /// Push a new entry onto the expression evaluation history.
  void pushEvalHistory(String expression) {
    if (_evalHistory.isNotEmpty && _evalHistory.last == expression) {
      return;
    }

    _evalHistory.add(expression);
    _historyPosition = -1;
  }

  bool get canNavigateUp {
    return _evalHistory.isNotEmpty && _historyPosition != 0;
  }

  void navigateUp() {
    if (_historyPosition == -1) {
      _historyPosition = _evalHistory.length - 1;
    } else if (_historyPosition > 0) {
      _historyPosition--;
    }
  }

  bool get canNavigateDown {
    return _evalHistory.isNotEmpty && _historyPosition != -1;
  }

  void navigateDown() {
    if (_historyPosition != -1) {
      _historyPosition++;
    }
    if (_historyPosition >= _evalHistory.length) {
      _historyPosition = -1;
    }
  }

  String get currentText {
    return _historyPosition == -1 ? null : _evalHistory[_historyPosition];
  }
}
