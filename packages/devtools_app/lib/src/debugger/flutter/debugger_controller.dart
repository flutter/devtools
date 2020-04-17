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
    autoDispose(_service.onStdoutEvent.listen(_handleStdoutEvent));
    autoDispose(_service.onStderrEvent.listen(_handleStderrEvent));
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

  /// Return the [ScriptList] active in the current isolate.
  ///
  /// See also [sortedScripts].
  ValueListenable<ScriptList> get scriptList => _scriptList;

  final _sortedScripts = ValueNotifier<List<ScriptRef>>([]);

  /// Return the sorted list of ScriptRefs active in the current isolate.
  ValueListenable<List<ScriptRef>> get sortedScripts => _sortedScripts;

  final _breakpoints = ValueNotifier<List<Breakpoint>>([]);

  ValueListenable<List<Breakpoint>> get breakpoints => _breakpoints;

  final _exceptionPauseMode = ValueNotifier<String>(null);

  ValueListenable<String> get exceptionPauseMode => _exceptionPauseMode;

  final _stdio = ValueNotifier<String>('');

  /// Return the stdout and stderr emitted from the application.
  ///
  /// Note that this output might be truncated after significant output.
  ValueListenable<String> get stdio => _stdio;

  IsolateRef isolateRef;

  List<ScriptRef> scripts;

  InstanceRef get reportedException => _reportedException;
  InstanceRef _reportedException;

  String commonScriptPrefix;

  LibraryRef get rootLib => _rootLib;
  LibraryRef _rootLib;

  // todo: is this called?
  set rootLib(LibraryRef rootLib) {
    print('set rootLib');

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

  /// Append to the stdout / stderr buffer.
  void appendStdio(String text) {
    // TODO(devoncarew): Check for greater than some amount of text and truncate
    // _stdio.value.
    _stdio.value += text;
  }

  void switchToIsolate(IsolateRef ref) async {
    isolateRef = ref;

    _isPaused.value = false;
    await _pause(false);

    _clearCaches();

    if (ref == null) {
      _breakpoints.value = [];
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

  Future<void> addBreakpoint(String scriptId, int line) =>
      _service.addBreakpoint(isolateRef.id, scriptId, line);

  Future<void> addBreakpointByPathFragment(String path, int line) async {
    final ref =
        scripts.firstWhere((ref) => ref.uri.endsWith(path), orElse: () => null);
    if (ref != null) {
      return addBreakpoint(ref.id, line);
    }
  }

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
        _breakpoints.value = [..._breakpoints.value, event.breakpoint];
        break;
      case EventKind.kBreakpointResolved:
        _breakpoints.value = [
          for (var b in _breakpoints.value) if (b != event.breakpoint) b,
          event.breakpoint
        ];
        break;
      case EventKind.kBreakpointRemoved:
        _breakpoints.value = [
          for (var b in _breakpoints.value) if (b != event.breakpoint) b
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
    // TODO(devoncarew): Change to reporting stdio along with information about whether
    // the event was stdout or stderr.
    appendStdio(text);
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

    // TODO(devoncarew): Follow up to see why we need to filter out non-unique
    // items here.
    final scriptRefs = Set.of(_scriptList.value.scripts).toList();
    scriptRefs.sort((a, b) {
      // We sort uppercase so that items like dart:foo sort before items like
      // dart:_foo.
      return a.uri.toUpperCase().compareTo(b.uri.toUpperCase());
    });
    _sortedScripts.value = scriptRefs;
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
