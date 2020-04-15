// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../auto_dispose.dart';
import '../../globals.dart';

/// Responsible for managing the debug state of the app.
class DebuggerController extends DisposableController
    with AutoDisposeControllerMixin {
  DebuggerController() {
    switchToIsolate(serviceManager.isolateManager.selectedIsolate);
    autoDispose(serviceManager.isolateManager.onSelectedIsolateChanged
        .listen(switchToIsolate));
    autoDispose(_service.onDebugEvent.listen(_handleIsolateEvent));
  }

  VmService get _service => serviceManager.service;

  final _scriptCache = <String, Script>{};

  final _isPaused = ValueNotifier<bool>(false);

  ValueListenable<bool> get isPaused => _isPaused;

  final _hasFrames = ValueNotifier<bool>(false);
  ValueNotifier<bool> _supportsStepping;

  ValueListenable<bool> get supportsStepping {
    return _supportsStepping ??= () {
      final notifier = ValueNotifier<bool>(_isPaused.value && _hasFrames.value);
      void update() {
        notifier.value = _isPaused.value && _hasFrames.value;
      }

      _isPaused.addListener(update);
      _hasFrames.addListener(update);
      return notifier;
    }();
  }

  Event lastEvent;

  final _currentScript = ValueNotifier<Script>(null);

  ValueListenable<Script> get currentScript => _currentScript;

  final _currentStack = ValueNotifier<Stack>(null);

  ValueListenable<Stack> get currentStack => _currentStack;

  final _scriptList = ValueNotifier<ScriptList>(null);

  ValueListenable<ScriptList> get scriptList => _scriptList;

  final _breakpoints = ValueNotifier<List<Breakpoint>>([]);

  ValueListenable<List<Breakpoint>> get breakpoints => _breakpoints;

  final _breakpointsWithLocation =
      ValueNotifier<List<BreakpointAndSourcePosition>>([]);

  ValueListenable<List<BreakpointAndSourcePosition>>
      get breakpointsWithLocation => _breakpointsWithLocation;

  final _exceptionPauseMode = ValueNotifier<String>(null);

  ValueListenable<String> get exceptionPauseMode => _exceptionPauseMode;

  IsolateRef isolateRef;

  List<ScriptRef> scripts;

  InstanceRef get reportedException => _reportedException;
  InstanceRef _reportedException;

  String commonScriptPrefix;

  LibraryRef get rootLib => _rootLib;
  LibraryRef _rootLib;

  set rootLib(LibraryRef rootLib) {
    _rootLib = rootLib;

    String scriptPrefix = rootLib.uri;
    if (scriptPrefix.startsWith('package:')) {
      scriptPrefix = scriptPrefix.substring(0, scriptPrefix.indexOf('/') + 1);
    } else if (scriptPrefix.contains('/lib/')) {
      scriptPrefix =
          scriptPrefix.substring(0, scriptPrefix.lastIndexOf('/lib/'));
      if (scriptPrefix.contains('/')) {
        scriptPrefix =
            scriptPrefix.substring(0, scriptPrefix.lastIndexOf('/') + 1);
      }
    } else if (scriptPrefix.contains('/bin/')) {
      scriptPrefix =
          scriptPrefix.substring(0, scriptPrefix.lastIndexOf('/bin/'));
      if (scriptPrefix.contains('/')) {
        scriptPrefix =
            scriptPrefix.substring(0, scriptPrefix.lastIndexOf('/') + 1);
      }
    } else if (scriptPrefix.contains('/test/')) {
      scriptPrefix =
          scriptPrefix.substring(0, scriptPrefix.lastIndexOf('/test/'));
      if (scriptPrefix.contains('/')) {
        scriptPrefix =
            scriptPrefix.substring(0, scriptPrefix.lastIndexOf('/') + 1);
      }
    } else {
      scriptPrefix = null;
    }

    commonScriptPrefix = scriptPrefix;
  }

  void switchToIsolate(IsolateRef ref) async {
    isolateRef = ref;

    _isPaused.value = false;
    await _pause(false);

    _clearCaches();

    if (ref == null) {
      _breakpoints.value = [];
      _breakpointsWithLocation.value = [];
      return;
    }

    final isolate = await _service.getIsolate(isolateRef.id);

    if (isolate.pauseEvent != null &&
        isolate.pauseEvent.kind != EventKind.kResume) {
      lastEvent = isolate.pauseEvent;
      _reportedException = isolate.pauseEvent.exception;
      await _pause(true);
    }

    _breakpoints.value = isolate.breakpoints;
    // todo: build _breakpointsWithLocation from _breakpoints

    _exceptionPauseMode.value = isolate.exceptionPauseMode;
  }

  Future<Success> pause() => _service.pause(isolateRef.id);

  Future<Success> resume() => _service.resume(isolateRef.id);

  Future<Success> stepOver() {
    // Handle async suspensions; issue StepOption.kOverAsyncSuspension.
    final useAsyncStepping = lastEvent?.atAsyncSuspension ?? false;
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

  Future<void> setExceptionPauseMode(String mode) =>
      _service.setExceptionPauseMode(isolateRef.id, mode);

  Future<Stack> getStack() => _service.getStack(isolateRef.id);

  void _handleIsolateEvent(Event event) async {
    if (event.isolate.id != isolateRef.id) return;

    _hasFrames.value = event.topFrame != null;
    lastEvent = event;

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
        print('kBreakpointAdded: ${event.breakpoint}');

        print(event.breakpoint.resolved);
        print(event.breakpoint.location.runtimeType);

        _breakpoints.value = [..._breakpoints.value, event.breakpoint];

        if (event.breakpoint.resolved) {
          BreakpointAndSourcePosition bp =
              BreakpointAndSourcePosition(event.breakpoint);

          // ignore: unawaited_futures
          getScript(bp.script).then((Script script) {
            SourcePosition pos = calculatePosition(script, bp.tokenPos);
            bp = BreakpointAndSourcePosition(event.breakpoint, pos);

            final list = _breakpointsWithLocation.value.toList();
            list.remove(bp);
            list.add(bp);
            list.sort();
            _breakpointsWithLocation.value = list;
          });
        } else {
          final list = [
            ..._breakpointsWithLocation.value,
            BreakpointAndSourcePosition(event.breakpoint),
          ]..sort();
          _breakpointsWithLocation.value = list;
        }

        break;
      case EventKind.kBreakpointResolved:
        print('kBreakpointResolved: ${event.breakpoint}');

        _breakpoints.value = [
          for (var b in _breakpoints.value) if (b != event.breakpoint) b,
          event.breakpoint
        ];

        BreakpointAndSourcePosition bp =
            BreakpointAndSourcePosition(event.breakpoint);

        // ignore: unawaited_futures
        getScript(bp.script).then((Script script) {
          SourcePosition pos = calculatePosition(script, bp.tokenPos);
          bp = BreakpointAndSourcePosition(event.breakpoint, pos);

          final list = _breakpointsWithLocation.value.toList();
          list.remove(bp);
          list.add(bp);
          list.sort();
          _breakpointsWithLocation.value = list;
        });

        break;
      case EventKind.kBreakpointRemoved:
        print('kBreakpointRemoved: ${event.breakpoint}');

        _breakpoints.value = [
          for (var b in _breakpoints.value) if (b != event.breakpoint) b
        ];

        _breakpointsWithLocation.value = [
          for (var b in _breakpointsWithLocation.value)
            if (b.breakpoint != event.breakpoint) b
        ];

        break;
    }
  }

  Future<void> _pause(bool pause) async {
    _isPaused.value = pause;
    _currentStack.value = await getStack();
    if (_currentStack.value != null && _currentStack.value.frames.isNotEmpty) {
      // TODO(https://github.com/flutter/devtools/issues/1648): Allow choice of
      // the scripts on the stack.
      _currentScript.value =
          await getScript(_currentStack.value.frames.first.location.script);
    }
  }

  void _clearCaches() {
    _scriptCache.clear();
    lastEvent = null;
    _reportedException = null;
  }

  /// Get the populated [Instance] object, given an [InstanceRef].
  ///
  /// The return value can be one of [Instance] or [Sentinel].
  Future<Object> getInstance(InstanceRef instanceRef) {
    return _service.getObject(isolateRef.id, instanceRef.id);
  }

  Future<Script> getScript(ScriptRef scriptRef) async {
    if (!_scriptCache.containsKey(scriptRef.id)) {
      _scriptCache[scriptRef.id] =
          await _service.getObject(isolateRef.id, scriptRef.id);
    }
    return _scriptCache[scriptRef.id];
  }

  Future<void> selectScript(ScriptRef ref) async {
    if (ref == null) return;
    _currentScript.value =
        await _service.getObject(isolateRef.id, ref.id) as Script;
  }

  Future<void> getScripts() async {
    _scriptList.value = await _service.getScripts(isolateRef.id);
  }

  SourcePosition calculatePosition(Script script, int tokenPos) {
    final List<List<int>> table = script.tokenPosTable;
    if (table == null) {
      return null;
    }

    for (List<int> row in table) {
      if (row == null || row.isEmpty) {
        continue;
      }
      final int line = row.elementAt(0);
      int index = 1;

      while (index < row.length - 1) {
        if (row.elementAt(index) == tokenPos) {
          return SourcePosition(line: line, column: row.elementAt(index + 1));
        }
        index += 2;
      }
    }

    return null;
  }

  int lineNumber(Script script, dynamic location) {
    if (script == null || location == null) {
      return null;
    }
    if (location is UnresolvedSourceLocation && location.line != null) {
      return location.line;
    } else if (location is SourceLocation) {
      return calculatePosition(script, location.tokenPos)?.line;
    }
    throw Exception(
      '$location should be a $UnresolvedSourceLocation or a $SourceLocation',
    );
  }

  String shortScriptName(String uri) {
    if (commonScriptPrefix == null) {
      return uri;
    }

    if (!uri.startsWith(commonScriptPrefix)) {
      return uri;
    }

    if (commonScriptPrefix.startsWith('package:')) {
      return uri.substring('package:'.length);
    } else {
      return uri.substring(commonScriptPrefix.length);
    }
  }
}

class SourcePosition {
  SourcePosition({@required this.line, @required this.column});

  final int line;
  final int column;

  @override
  String toString() => '$line $column';
}

/// A tuple of a breakpoint and a source position.
class BreakpointAndSourcePosition
    implements Comparable<BreakpointAndSourcePosition> {
  BreakpointAndSourcePosition(this.breakpoint, [this.sourcePosition]);

  final Breakpoint breakpoint;
  final SourcePosition sourcePosition;

  bool get resolved => breakpoint.resolved;

  ScriptRef get script {
    if (breakpoint.location is UnresolvedSourceLocation) {
      final UnresolvedSourceLocation location = breakpoint.location;
      return location.script;
    } else if (breakpoint.location is SourceLocation) {
      final SourceLocation location = breakpoint.location;
      return location.script;
    } else {
      return null;
    }
  }

  String get scriptUri {
    if (breakpoint.location is UnresolvedSourceLocation) {
      final UnresolvedSourceLocation location = breakpoint.location;
      return location.script?.uri ?? location.scriptUri;
    } else if (breakpoint.location is SourceLocation) {
      final SourceLocation location = breakpoint.location;
      return location.script.uri;
    } else {
      return null;
    }
  }

  int get line {
    if (sourcePosition != null) {
      return sourcePosition.line;
    } else if (breakpoint.location is UnresolvedSourceLocation) {
      final UnresolvedSourceLocation location = breakpoint.location;
      return location.line;
    } else {
      return null;
    }
  }

  int get column {
    if (sourcePosition != null) {
      return sourcePosition.column;
    } else if (breakpoint.location is UnresolvedSourceLocation) {
      final UnresolvedSourceLocation location = breakpoint.location;
      return location.column;
    } else {
      return null;
    }
  }

  int get tokenPos {
    if (breakpoint.location is UnresolvedSourceLocation) {
      final UnresolvedSourceLocation location = breakpoint.location;
      return location.tokenPos;
    } else if (breakpoint.location is SourceLocation) {
      final SourceLocation location = breakpoint.location;
      return location.tokenPos;
    } else {
      return null;
    }
  }

  @override
  int get hashCode => breakpoint.hashCode;

  @override
  bool operator ==(other) {
    return other is BreakpointAndSourcePosition &&
        other.breakpoint == breakpoint;
  }

  @override
  int compareTo(BreakpointAndSourcePosition other) {
    final result = scriptUri.compareTo(other.scriptUri);
    if (result != 0) return result;

    if (resolved != other.resolved) return resolved ? 1 : -1;

    if (resolved) {
      return tokenPos - other.tokenPos;
    } else {
      return line - other.line;
    }
  }
}
