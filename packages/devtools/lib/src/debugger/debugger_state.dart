// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import '../debugger/debugger.dart';
import '../ui/analytics.dart' as ga;

class DebuggerState {
  VmService _service;

  StreamSubscription<Event> _debugSubscription;

  IsolateRef isolateRef;
  List<ScriptRef> scripts;

  final Map<String, Script> _scriptCache = <String, Script>{};

  final BehaviorSubject<bool> _paused = BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<bool> _supportsStepping =
      BehaviorSubject<bool>.seeded(false);

  Event lastEvent;

  final BehaviorSubject<List<Breakpoint>> _breakpoints =
      BehaviorSubject<List<Breakpoint>>.seeded(<Breakpoint>[]);

  final BehaviorSubject<String> _exceptionPauseMode = BehaviorSubject();

  InstanceRef _reportedException;

  bool get isPaused => _paused.value;

  Stream<bool> get onPausedChanged => _paused;

  Stream<bool> get onSupportsStepping =>
      Observable<bool>.concat(<Stream<bool>>[_paused, _supportsStepping]);

  Stream<List<Breakpoint>> get onBreakpointsChanged => _breakpoints;

  Stream<String> get onExceptionPauseModeChanged => _exceptionPauseMode;

  List<Breakpoint> get breakpoints => _breakpoints.value;

  void setVmService(VmService service) {
    _service = service;

    _debugSubscription = _service.onDebugEvent.listen(_handleIsolateEvent);
  }

  void switchToIsolate(IsolateRef ref) async {
    isolateRef = ref;

    _updatePaused(false);

    _clearCaches();

    if (ref == null) {
      _breakpoints.add(<Breakpoint>[]);
      return;
    }

    final dynamic result = await _service.getIsolate(isolateRef.id);
    if (result is Isolate) {
      final Isolate isolate = result;

      if (isolate.pauseEvent != null &&
          isolate.pauseEvent.kind != EventKind.kResume) {
        lastEvent = isolate.pauseEvent;
        _reportedException = isolate.pauseEvent.exception;
        _updatePaused(true);
      }

      _breakpoints.add(isolate.breakpoints);

      _exceptionPauseMode.add(isolate.exceptionPauseMode);
    }
  }

  Future<Success> pause() => _service.pause(isolateRef.id);

  Future<Success> resume() => _service.resume(isolateRef.id);

  Future<Success> stepOver() {
    ga.select(ga.debugger, ga.stepOver);

    // Handle async suspensions; issue StepOption.kOverAsyncSuspension.
    final bool useAsyncStepping = lastEvent?.atAsyncSuspension == true;
    return _service.resume(isolateRef.id,
        step: useAsyncStepping
            ? StepOption.kOverAsyncSuspension
            : StepOption.kOver);
  }

  Future<Success> stepIn() {
    ga.select(ga.debugger, ga.stepIn);

    return _service.resume(isolateRef.id, step: StepOption.kInto);
  }

  Future<Success> stepOut() {
    ga.select(ga.debugger, ga.stepOut);

    return _service.resume(isolateRef.id, step: StepOption.kOut);
  }

  Future<void> clearBreakpoints() async {
    final List<Breakpoint> breakpoints = _breakpoints.value.toList();
    await Future.forEach(breakpoints, (Breakpoint breakpoint) {
      return removeBreakpoint(breakpoint);
    });
  }

  Future<void> addBreakpoint(String scriptId, int line) {
    return _service.addBreakpoint(isolateRef.id, scriptId, line);
  }

  Future<void> addBreakpointByPathFragment(String path, int line) async {
    final ScriptRef ref =
        scripts.firstWhere((ref) => ref.uri.endsWith(path), orElse: () => null);
    if (ref != null) {
      return _service.addBreakpoint(isolateRef.id, ref.id, line);
    }
  }

  Future<void> removeBreakpoint(Breakpoint breakpoint) {
    return _service.removeBreakpoint(isolateRef.id, breakpoint.id);
  }

  Future<void> setExceptionPauseMode(String mode) {
    return _service.setExceptionPauseMode(isolateRef.id, mode);
  }

  Future<Stack> getStack() {
    return _service.getStack(isolateRef.id);
  }

  InstanceRef get reportedException => _reportedException;

  void _handleIsolateEvent(Event event) {
    if (event.isolate.id != isolateRef.id) {
      return;
    }

    _supportsStepping.add(event.topFrame != null);
    lastEvent = event;

    switch (event.kind) {
      case EventKind.kResume:
        _updatePaused(false);
        _reportedException = null;
        break;
      case EventKind.kPauseStart:
      case EventKind.kPauseExit:
      case EventKind.kPauseBreakpoint:
      case EventKind.kPauseInterrupted:
      case EventKind.kPauseException:
      case EventKind.kPausePostRequest:
        _reportedException = event.exception;
        _updatePaused(true);
        break;
      case EventKind.kBreakpointAdded:
        _breakpoints.value.add(event.breakpoint);
        _breakpoints.add(_breakpoints.value);
        break;
      case EventKind.kBreakpointResolved:
        _breakpoints.value.remove(event.breakpoint);
        _breakpoints.value.add(event.breakpoint);
        _breakpoints.add(_breakpoints.value);
        break;
      case EventKind.kBreakpointRemoved:
        _breakpoints.value.remove(event.breakpoint);
        _breakpoints.add(_breakpoints.value);
        break;
    }
  }

  void _clearCaches() {
    _scriptCache.clear();
    lastEvent = null;
    _reportedException = null;
  }

  void dispose() {
    _debugSubscription?.cancel();
  }

  void _updatePaused(bool value) {
    if (_paused.value != value) {
      _paused.add(value);
    }
  }

  /// Get the populated [Instance] object, given an [InstanceRef].
  ///
  /// The return value can be one of [Instance] or [Sentinel].
  Future<dynamic> getInstance(InstanceRef instanceRef) {
    return _service.getObject(isolateRef.id, instanceRef.id);
  }

  Future<Script> getScript(ScriptRef scriptRef) async {
    if (!_scriptCache.containsKey(scriptRef.id)) {
      _scriptCache[scriptRef.id] =
          await _service.getObject(isolateRef.id, scriptRef.id);
    }

    return _scriptCache[scriptRef.id];
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
          return SourcePosition(line, row.elementAt(index + 1));
        }
        index += 2;
      }
    }

    return null;
  }

  String commonScriptPrefix;
  LibraryRef rootLib;

  void setRootLib(LibraryRef rootLib) {
    this.rootLib = rootLib;

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

  String getShortScriptName(String uri) {
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

  void updateFrom(Isolate isolate) {
    _breakpoints.add(isolate.breakpoints);
  }
}
