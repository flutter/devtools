// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Stack;
import 'package:vm_service/vm_service.dart';

import '../../auto_dispose.dart';
import '../../config_specific/logger/logger.dart';
import '../../globals.dart';
import 'debugger_model.dart';

// TODO(devoncarew): Add some delayed resume value notifiers (to be used to
// help debounce stepping operations).

/// Responsible for managing the debug state of the app.
class DebuggerController extends DisposableController
    with AutoDisposeControllerMixin {
  DebuggerController() {
    switchToIsolate(serviceManager.isolateManager.selectedIsolate);
    autoDispose(serviceManager.isolateManager.onSelectedIsolateChanged
        .listen(switchToIsolate));
    autoDispose(_service.onDebugEvent.listen(_handleIsolateEvent));
    autoDispose(_service.onStdoutEvent.listen(_handleStdoutEvent));
    autoDispose(_service.onStderrEvent.listen(_handleStderrEvent));
  }

  VmService get _service => serviceManager.service;

  final _scriptCache = <String, Script>{};

  final _isPaused = ValueNotifier<bool>(false);

  ValueListenable<bool> get isPaused => _isPaused;

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

  final _sortedClasses = ValueNotifier<List<ClassRef>>([]);

  /// Return the sorted list of ClassRefs active in the current isolate.
  ValueListenable<List<ClassRef>> get sortedClasses => _sortedClasses;

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

  /// Return the stdout and stderr emitted from the application.
  ///
  /// Note that this output might be truncated after significant output.
  ValueListenable<List<String>> get stdio => _stdio;

  IsolateRef isolateRef;

  InstanceRef get reportedException => _reportedException;
  InstanceRef _reportedException;

  /// Append to the stdout / stderr buffer.
  void appendStdio(String text) {
    const int kMaxLogItemsLowerBound = 5000;
    const int kMaxLogItemsUpperBound = 5500;

    // Parse out the new lines and append to the end of the existing lines.
    var lines = _stdio.value.toList();
    final newLines = text.split('\n');

    if (lines.isNotEmpty && !lines.last.endsWith('\n')) {
      lines[lines.length - 1] = '${lines[lines.length - 1]}${newLines.first}';
      if (newLines.length > 1) {
        lines.addAll(newLines.sublist(1));
      }
    } else {
      lines.addAll(newLines);
    }

    // For performance reasons, we drop older lines in batches, so the lines
    // will grow to kMaxLogItemsUpperBound then truncate to
    // kMaxLogItemsLowerBound.
    if (lines.length > kMaxLogItemsUpperBound) {
      lines = lines.sublist(lines.length - kMaxLogItemsLowerBound);
    }

    _stdio.value = lines;
  }

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
      _reportedException = isolate.pauseEvent.exception;
      await _pause(true);
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

  Future<Success> resume() => _service.resume(isolateRef.id);

  Future<Success> stepOver() {
    // Handle async suspensions; issue StepOption.kOverAsyncSuspension.
    final useAsyncStepping = _lastEvent?.atAsyncSuspension ?? false;
    return _service.resume(
      isolateRef.id,
      step:
          useAsyncStepping ? StepOption.kOverAsyncSuspension : StepOption.kOver,
    );
  }

  Future<Success> stepIn() =>
      _service.resume(isolateRef.id, step: StepOption.kInto);

  Future<Success> stepOut() =>
      _service.resume(isolateRef.id, step: StepOption.kOut);

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

  void _handleIsolateEvent(Event event) async {
    if (event.isolate.id != isolateRef.id) return;

    _hasFrames.value = event.topFrame != null;
    _lastEvent = event;

    switch (event.kind) {
      case EventKind.kResume:
        await _pause(false);
        _reportedException = null;
        break;
      case EventKind.kPauseStart:
      case EventKind.kPauseExit:
      case EventKind.kPauseBreakpoint:
      case EventKind.kPauseInterrupted:
      case EventKind.kPauseException:
      case EventKind.kPausePostRequest:
        _reportedException = event.exception;
        await _pause(true);
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
          for (var b in _breakpoints.value)
            if (b != event.breakpoint) b,
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
        _breakpoints.value = [
          for (var b in _breakpoints.value)
            if (b != event.breakpoint) b
        ];

        _breakpointsWithLocation.value = [
          for (var b in _breakpointsWithLocation.value)
            if (b.breakpoint != event.breakpoint) b
        ];

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

  Future<void> _pause(bool pause) async {
    _isPaused.value = pause;

    final stack = pause ? await _service.getStack(isolateRef.id) : null;
    final frames = _framesForCallStack(stack);

    _stackFramesWithLocation.value =
        await Future.wait(frames.map(_createStackFrameWithLocation));
    if (_stackFramesWithLocation.value.isEmpty) {
      selectStackFrame(null);
    } else {
      selectStackFrame(_stackFramesWithLocation.value.first);
    }
  }

  void _clearCaches() {
    _scriptCache.clear();
    _lastEvent = null;
    _reportedException = null;
  }

  /// Get the populated [Obj] object, given an [ObjRef].
  ///
  /// The return value can be one of [Obj] or [Sentinel].
  Future<Obj> getObject(ObjRef objRef) {
    return _service.getObject(isolateRef.id, objRef.id);
  }

  /// Return a cached [Script] for the given [ScriptRef], returning null
  /// if there is no cahced [Script].
  Script getScriptCached(ScriptRef scriptRef) {
    // Check to see if this ScriptRef is really a Script.
    if (scriptRef is Script) {
      if (_scriptCache[scriptRef.id] == null) {
        _scriptCache[scriptRef.id] = scriptRef;
      }

      return scriptRef;
    }

    return _scriptCache[scriptRef?.id];
  }

  /// Retrieve the [Script] for the given [ScritpRef].
  ///
  /// This caches the script lookup for future invocations.
  Future<Script> getScript(ScriptRef scriptRef) async {
    if (!_scriptCache.containsKey(scriptRef.id)) {
      _scriptCache[scriptRef.id] =
          await _service.getObject(isolateRef.id, scriptRef.id);
    }
    return _scriptCache[scriptRef.id];
  }

  /// Return the [ScriptRef] at the given [uri].
  ScriptRef scriptRefForUri(String uri) {
    return _uriToScriptMap[uri];
  }

  Future<void> _populateScripts(Isolate isolate) async {
    final scriptList = await _service.getScripts(isolateRef.id);
    // We filter out non-unique ScriptRefs here (dart-lang/sdk/issues/41661).
    final scriptRefs = Set.of(scriptList.scripts).toList();
    scriptRefs.sort((a, b) {
      // We sort uppercase so that items like dart:foo sort before items like
      // dart:_foo.
      return a.uri.toUpperCase().compareTo(b.uri.toUpperCase());
    });
    _sortedScripts.value = scriptRefs;

    try {
      final classList = await _service.getClassList(isolateRef.id);
      final classes = classList.classes
          .where((c) => c?.name != null && c.name.isNotEmpty)
          .toList();
      classes.sort((ClassRef a, ClassRef b) {
        // We sort uppercase so that items like Foo sort before items like _Foo.
        return a.name.toUpperCase().compareTo(b.name.toUpperCase());
      });
      _sortedClasses.value = classes;
    } catch (e, st) {
      // Fail gracefully - not all clients support getClassList().
      log('$e\n$st');
    }

    for (var scriptRef in scriptRefs) {
      _uriToScriptMap[scriptRef.uri] = scriptRef;
    }

    // Update the selected script.
    final mainScriptRef = scriptRefs.firstWhere((ref) {
      return ref.uri == isolate.rootLib.uri;
    }, orElse: () => null);

    showScriptLocation(ScriptLocation(mainScriptRef));
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
    if (!variable.isExpandable || variable.treeInitialized) return;

    final InstanceRef instanceRef = variable.boundVar.value;
    try {
      final dynamic result = await getObject(instanceRef);
      if (result is Instance) {
        if (result.associations != null) {
          variable.addAllChildren(_createVariablesForAssociations(result));
        } else if (result.elements != null) {
          variable.addAllChildren(_createVariablesForElements(result));
        } else if (result.fields != null) {
          variable.addAllChildren(_createVariablesForFields(result));
        }
      }
    } on SentinelException catch (_) {
      // Fail gracefully if calling `getObject` throws a SentinelException.
    }
    variable.treeInitialized = true;
  }

  List<Variable> _createVariablesForAssociations(Instance instance) {
    return instance.associations
        .map((MapAssociation assoc) {
          // For string keys, quote the key value.
          String keyString = assoc.key.valueAsString;
          // TODO(kenz): for maps where keys are not primitive types, support
          // expanding the keys as well as the values.
          if (assoc.key is InstanceRef &&
              assoc.key.kind == InstanceKind.kString) {
            keyString = "'$keyString'";
          }
          return BoundVariable(
            name: '[$keyString]',
            value: assoc.value,
            scopeStartTokenPos: null,
            scopeEndTokenPos: null,
            declarationTokenPos: null,
          );
        })
        .map((bv) => Variable.create(bv))
        .toList();
  }

  List<Variable> _createVariablesForElements(Instance instance) {
    final List<BoundVariable> boundVars = [];
    for (int i = 0; i < instance.elements.length; i++) {
      final value = instance.elements[i];
      boundVars.add(BoundVariable(
        name: '$i:',
        value: value,
        scopeStartTokenPos: null,
        scopeEndTokenPos: null,
        declarationTokenPos: null,
      ));
    }
    return boundVars.map((bv) => Variable.create(bv)).toList();
  }

  List<Variable> _createVariablesForFields(Instance instance) {
    return instance.fields
        .map((BoundField field) {
          return BoundVariable(
            name: field.decl.name,
            value: field.value,
            scopeStartTokenPos: null,
            scopeEndTokenPos: null,
            declarationTokenPos: null,
          );
        })
        .map((bv) => Variable.create(bv))
        .toList();
  }

  List<Frame> _framesForCallStack(Stack stack) {
    if (stack == null) return [];

    List<Frame> frames = stack.asyncCausalFrames ?? stack.frames;

    // Handle breaking-on-exceptions.
    if (_reportedException != null && frames.isNotEmpty) {
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
          value: _reportedException,
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
