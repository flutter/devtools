// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../auto_dispose.dart';
import '../../core/message_bus.dart';
import '../../globals.dart';

// Note: don't check this in enabled.
/// Used to debug service protocol traffic. All requests to to the VM service
/// connection are logged to the Logging page, as well as all responses and
/// events from the service protocol device.
const debugLogServiceProtocolEvents = false;

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

    if (debugLogServiceProtocolEvents) {
      autoDispose(_service.onSend.listen(_logServiceProtocolCalls));
      autoDispose(_service.onReceive.listen(_logServiceProtocolResponses));
    }
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

  Event _lastEvent;

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

  final _breakpointsWithLocation =
      ValueNotifier<List<BreakpointAndSourcePosition>>([]);

  ValueListenable<List<BreakpointAndSourcePosition>>
      get breakpointsWithLocation => _breakpointsWithLocation;

  final _exceptionPauseMode = ValueNotifier<String>(null);

  ValueListenable<String> get exceptionPauseMode => _exceptionPauseMode;

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
    if (breakpoints.value != null) {
      // ignore: unawaited_futures
      Future.wait(breakpoints.value.map(_createBreakpointWithLocation))
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

  Future<void> setExceptionPauseMode(String mode) =>
      _service.setExceptionPauseMode(isolateRef.id, mode);

  Future<Stack> getStack() => _service.getStack(isolateRef.id);

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

  void _logServiceProtocolCalls(String message) {
    final Map m = jsonDecode(message);

    final String method = m['method'];
    final String id = m['id'];

    messageBus.addEvent(BusEvent(
      'devtools.debugger',
      data: '⇨ #$id $method()\n$message',
    ));
  }

  void _logServiceProtocolResponses(String message) {
    final Map m = jsonDecode(message);

    String details = m['method'];
    if (details == null) {
      if (m['result'] != null) {
        details = m['result']['type'];
      } else {
        details = m['error'] ?? '';
      }
    } else if (details == 'streamNotify') {
      details = '';
    }

    final String id = m['id'];
    var streamId = '';
    var kind = '';

    if (m['params'] != null) {
      final Map p = m['params'];
      streamId = p['streamId'];

      if (p['event'] != null) {
        kind = p['event']['extensionKind'] ?? p['event']['kind'];
      }
    }

    messageBus.addEvent(BusEvent(
      'devtools.debugger',
      data: '  ⇦ ${id == null ? '' : '#$id '}$details$streamId $kind\n$message',
    ));
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
    _lastEvent = null;
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

  Future<void> _populateScripts(Isolate isolate) async {
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

    // Update the selected script.
    final mainScriptRef = _scriptList.value.scripts.firstWhere((ref) {
      return ref.uri == isolate.rootLib.uri;
    }, orElse: () => null);
    await selectScript(mainScriptRef);
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

  Future<BreakpointAndSourcePosition> _createBreakpointWithLocation(
      Breakpoint breakpoint) async {
    if (breakpoint.resolved) {
      final bp = BreakpointAndSourcePosition(breakpoint);
      return getScript(bp.script).then((Script script) {
        final pos = calculatePosition(script, bp.tokenPos);
        return BreakpointAndSourcePosition(breakpoint, pos);
      });
    } else {
      return BreakpointAndSourcePosition(breakpoint);
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

  String get id => breakpoint.id;

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
