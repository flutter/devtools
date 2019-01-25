// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;

import 'package:codemirror/codemirror.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import '../framework/framework.dart';
import '../globals.dart';
import '../ui/custom.dart';
import '../ui/elements.dart';
import '../ui/primer.dart';
import '../ui/split.dart' as split;
import '../ui/ui_utils.dart';
import '../utils.dart';

// TODO(devoncarew): allow browsing object fields

// TODO(devoncarew): improve selection behavior in the left nav area

// TODO(devoncarew): have the console area be collapsible

// TODO(devoncarew): handle cases of isolates terminating and new isolates
// replacing them (flutter hot restart)

// TODO(devoncarew): show toasts for some events (new isolate creation)

// TODO(devoncarew): handle displaying lists and maps in the variables view

// TODO(devoncarew): handle displaying large lists, maps, in the variables view

class DebuggerScreen extends Screen {
  DebuggerScreen()
      : debuggerState = DebuggerState(),
        super(name: 'Debugger', id: 'debugger', iconClass: 'octicon-bug') {
    deviceStatus = StatusItem();
    addStatusItem(deviceStatus);
  }

  final DebuggerState debuggerState;

  bool _initialized = false;

  StatusItem deviceStatus;

  CoreElement _breakpointsCountDiv;
  CoreElement _sourcePathDiv;

  SourceEditor sourceEditor;
  CallStackView callStackView;
  VariablesView variablesView;
  BreakpointsView breakpointsView;
  ScriptsView scriptsView;
  ConsoleArea consoleArea;

  @override
  CoreElement createContent(Framework framework) {
    final CoreElement screenDiv = div()..layoutVertical();

    CoreElement sourceArea;
    CoreElement consoleDiv;

    final PButton resumeButton = PButton()
      ..primary()
      ..small()
      ..clazz('margin-left')
      ..disabled = true
      ..add(<CoreElement>[
        span(c: 'octicon octicon-triangle-right'),
        span(text: 'Resume'),
      ]);
    resumeButton.click(() async {
      resumeButton.disabled = true;
      await debuggerState.resume();
      resumeButton.disabled = false;
    });

    final PButton pauseButton = PButton()
      ..small()
      ..add(<CoreElement>[
        span(c: 'octicon octicon-primitive-dot'),
        span(text: 'Pause'),
      ]);
    pauseButton.click(() async {
      pauseButton.disabled = true;
      await debuggerState.pause();
      pauseButton.disabled = false;
    });

    debuggerState.onPausedChanged.listen((bool isPaused) {
      resumeButton.disabled = !isPaused;
      pauseButton.disabled = isPaused;
    });

    PButton stepOver, stepIn, stepOut;

    final BreakOnExceptionControl breakOnExceptionControl =
        BreakOnExceptionControl();
    breakOnExceptionControl.onPauseModeChanged.listen((String mode) {
      debuggerState.setExceptionPauseMode(mode);
    });
    debuggerState.onExceptionPauseModeChanged.listen((String mode) {
      breakOnExceptionControl.exceptionPauseMode = mode;
    });

    consoleArea = ConsoleArea();
    List<CoreElement> navEditorPanels;

    screenDiv.add(<CoreElement>[
      div(c: 'section')
        ..flex()
        ..layoutHorizontal()
        ..add(navEditorPanels = <CoreElement>[
          div(c: 'debugger-menu')
            ..layoutVertical()
            ..add(<CoreElement>[
              _buildMenuNav(),
            ]),
          div()
            ..element.style.overflowX = 'hidden'
            ..layoutVertical()
            ..add(<CoreElement>[
              div(c: 'section')
                ..layoutHorizontal()
                ..add(<CoreElement>[
                  pauseButton,
                  resumeButton,
                  div(c: 'btn-group flex-no-wrap margin-left')
                    ..add(<CoreElement>[
                      stepIn = PButton()
                        ..add(<CoreElement>[
                          span(c: 'octicon octicon-chevron-down'),
                          span(text: 'Step in'),
                        ])
                        ..small(),
                      stepOver = PButton()
                        ..add(<CoreElement>[
                          span(c: 'octicon octicon-chevron-right'),
                          span(text: 'Step over'),
                        ])
                        ..small(),
                      stepOut = PButton()
                        ..add(<CoreElement>[
                          span(c: 'octicon octicon-chevron-up'),
                          span(text: 'Step out'),
                        ])
                        ..small(),
                    ]),
                  div()..flex(),
                  breakOnExceptionControl,
                ]),
              sourceArea = div(c: 'section table-border')
                ..layoutVertical()
                ..add(<CoreElement>[
                  _sourcePathDiv = div(c: 'source-head'),
                ]),
              consoleDiv = div(c: 'section table-border')
                ..layoutVertical()
                ..add(consoleArea.element),
            ]),
        ]),
    ]);

    _sourcePathDiv.setInnerHtml('&nbsp;');

    // configure the navigation / editor splitter
    split.flexSplit(
      navEditorPanels,
      gutterSize: defaultSplitterWidth,
      sizes: [22, 78],
      minSize: [200, 600],
    );

    // configure the editor / console splitter
    split.flexSplit(
      [sourceArea, consoleDiv],
      horizontal: false,
      gutterSize: defaultSplitterWidth,
      sizes: [80, 20],
      minSize: [200, 60],
    );

    debuggerState.onSupportsStepping.listen((bool value) {
      stepIn.enabled = value;

      // Only enable step over and step out if we're paused at a frame. When
      // paused w/o a frame (in the message loop), step over and out aren't
      // meaningful (and also crash the vm:
      // https://github.com/dart-lang/sdk/issues/35601).
      stepOver.enabled = value && (debuggerState._lastEvent.topFrame != null);
      stepOut.enabled = value && (debuggerState._lastEvent.topFrame != null);
    });

    stepOver.click(() => debuggerState.stepOver());
    stepIn.click(() => debuggerState.stepIn());
    stepOut.click(() => debuggerState.stepOut());

    final Map<String, dynamic> options = <String, dynamic>{
      'mode': 'dart',
      'lineNumbers': true,
      'gutters': <String>['breakpoints'],
    };
    final CodeMirror codeMirror =
        CodeMirror.fromElement(sourceArea.element, options: options);
    codeMirror.setReadOnly(true);
    final codeMirrorElement = _sourcePathDiv.element.parent.children[1];
    codeMirrorElement.setAttribute('flex', '');

    sourceEditor = SourceEditor(codeMirror, debuggerState);

    debuggerState.onBreakpointsChanged
        .listen((List<Breakpoint> breakpoints) async {
      sourceEditor.setBreakpoints(breakpoints);
    });

    debuggerState.onPausedChanged.listen((bool paused) async {
      if (paused) {
        // Check for async causal frames; fall back to using regular sync frames.
        final Stack stack = await debuggerState.getStack();
        List<Frame> frames = stack.asyncCausalFrames ?? stack.frames;

        // Handle breaking-on-exceptions.
        final InstanceRef reportedException = debuggerState.reportedException;
        if (reportedException != null && frames.isNotEmpty) {
          final Frame frame = frames.first;

          final Frame newFrame = Frame()
            ..type = frame.type
            ..index = frame.index
            ..function = frame.function
            ..code = frame.code
            ..location = frame.location
            ..kind = frame.kind;

          final List<BoundVariable> newVars = <BoundVariable>[];
          newVars.add(BoundVariable()
            ..name = '<exception>'
            ..value = reportedException);
          newVars.addAll(frame.vars ?? []);
          newFrame.vars = newVars;

          frames = <Frame>[newFrame]..addAll(frames.sublist(1));
        }

        callStackView.showFrames(frames, selectTop: true);
      } else {
        callStackView.clearFrames();
        sourceEditor.clearExecutionPoint();
      }
    });

    // Update the status line.
    debuggerState.onPausedChanged.listen((bool paused) async {
      if (paused && debuggerState._lastEvent.topFrame != null) {
        final Frame topFrame = debuggerState._lastEvent.topFrame;

        final ScriptRef scriptRef = topFrame.location.script;
        final Script script = await debuggerState.getScript(scriptRef);
        final SourcePosition position =
            debuggerState.calculatePosition(script, topFrame.location.tokenPos);

        final String file =
            scriptRef.uri.substring(scriptRef.uri.lastIndexOf('/') + 1);
        deviceStatus.element.text = '$file:${position.line}:${position.column}';
      } else {
        deviceStatus.element.text = '';
      }
    });

    callStackView.onSelectionChanged.listen((Frame frame) async {
      if (frame == null) {
        callStackView.clearFrames();
        variablesView.clearVariables();
        sourceEditor.clearExecutionPoint();
      } else {
        final SourceLocation location = frame.location;

        if (location != null) {
          final ScriptRef scriptRef = location.script;
          final Script script = await debuggerState.getScript(scriptRef);
          final SourcePosition position =
              debuggerState.calculatePosition(script, location.tokenPos);
          _sourcePathDiv.text = script.uri;
          sourceEditor.displayExecutionPoint(script, position: position);
        }

        variablesView.showVariables(frame);
      }
    });

    consoleArea.refresh();

    return screenDiv;
  }

  @override
  void entering() {
    if (!_initialized) {
      _initialize();
    }

    // TODO(devoncarew): On restoring the page, the execution point marker can
    // get out of position
  }

  void _initialize() {
    _initialized = true;

    serviceManager.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceManager.hasConnection) {
      _handleConnectionStart(serviceManager.service);
    }
    serviceManager.isolateManager.onSelectedIsolateChanged
        .listen(_handleIsolateChanged);
    serviceManager.onConnectionClosed.listen(_handleConnectionStop);
  }

  CoreElement _buildMenuNav() {
    callStackView = CallStackView();

    final VariableDescriber describer = (BoundVariable variable) async {
      if (variable == null) {
        return null;
      }

      final dynamic value = variable.value;

      if (value is Sentinel) {
        return value.valueAsString;
      }

      if (value is TypeArgumentsRef) {
        return value.name;
      }

      final InstanceRef ref = value;

      if (ref.valueAsString != null && !ref.valueAsStringIsTruncated) {
        return ref.valueAsString;
      } else {
        final dynamic result = await serviceManager.service.invoke(
            debuggerState.isolateRef.id, ref.id, 'toString', <String>[]);
        if (result is ErrorRef) {
          return '${result.kind} ${result.message}';
        } else if (result is InstanceRef) {
          final String str = await _retrieveFullStringValue(result);
          return str;
        }
      }
    };
    variablesView = VariablesView(describer);

    _breakpointsCountDiv = span(text: '0', c: 'counter');
    breakpointsView = BreakpointsView(
        _breakpointsCountDiv, debuggerState, debuggerState.getShortScriptName);
    breakpointsView.onDoubleClick.listen((Breakpoint breakpoint) async {
      final dynamic location = breakpoint.location;
      if (location is SourceLocation) {
        final Script script = await debuggerState.getScript(location.script);
        final SourcePosition pos =
            debuggerState.calculatePosition(script, location.tokenPos);
        sourceEditor.displayScript(script,
            scrollTo: SourcePosition(pos.line - 1));
      } else if (location is UnresolvedSourceLocation) {
        final Script script = await debuggerState.getScript(location.script);
        sourceEditor.displayScript(script,
            scrollTo: SourcePosition(location.line - 1));
      }
    });

    CoreElement scriptCountDiv;
    scriptsView = ScriptsView(debuggerState.getShortScriptName);
    scriptsView.onSelectionChanged.listen((ScriptRef scriptRef) async {
      if (scriptRef == null) {
        _displaySource(null);
        return;
      }

      final IsolateRef isolateRef =
          serviceManager.isolateManager.selectedIsolate;
      final dynamic result =
          await serviceManager.service.getObject(isolateRef.id, scriptRef.id);

      if (result is Script) {
        _displaySource(result);
      } else {
        _displaySource(null);
      }
    });
    scriptsView.onScriptsChanged.listen((_) {
      scriptCountDiv.text = scriptsView.items.length.toString();
    });

    final PNavMenu menu = PNavMenu(<CoreElement>[
      PNavMenuItem('Call stack')
        ..click(() => callStackView.element.toggleAttribute('hidden')),
      callStackView.element,
      PNavMenuItem('Variables')
        ..click(() => variablesView.element.toggleAttribute('hidden')),
      variablesView.element,
      PNavMenuItem('Breakpoints')
        ..add(_breakpointsCountDiv)
        ..click(() => breakpointsView.element.toggleAttribute('hidden')),
      breakpointsView.element,
      PNavMenuItem('Scripts')
        ..add(
          scriptCountDiv = span(text: '0', c: 'counter'),
        )
        ..click(() => scriptsView.element.toggleAttribute('hidden')),
      scriptsView.element,
    ], supportsSelection: false)
      ..flex()
      ..layoutVertical();

    debuggerState.onBreakpointsChanged.listen((List<Breakpoint> breakpoints) {
      breakpointsView.showBreakpoints(breakpoints);
    });

    return menu;
  }

  void _handleConnectionStart(VmService service) {
    debuggerState.setVmService(serviceManager.service);

    service.onStdoutEvent.listen((Event e) {
      final String message = decodeBase64(e.bytes);
      consoleArea.appendText(message);
    });

    service.onStderrEvent.listen((Event e) {
      final String message = decodeBase64(e.bytes);
      consoleArea.appendText(message);
    });

    if (serviceManager.isolateManager.selectedIsolate != null) {
      _handleIsolateChanged(serviceManager.isolateManager.selectedIsolate);
    }
  }

  void _handleIsolateChanged(IsolateRef isolateRef) {
    if (isolateRef == null) {
      scriptsView.clearScripts();

      debuggerState.switchToIsolate(isolateRef);

      return;
    }

    if (isolateRef == debuggerState.isolateRef) {
      return;
    }

    debuggerState.switchToIsolate(isolateRef);

    serviceManager.service.getIsolate(isolateRef.id).then((dynamic result) {
      if (result is Isolate) {
        _populateFromIsolate(result);
      } else {
        scriptsView.clearScripts();
      }
    }).catchError((dynamic e) {
      framework.showError('Error retrieving isolate information', e);
    });
  }

  void _handleConnectionStop(dynamic event) {
    deviceStatus.element.text = '';

    scriptsView.clearScripts();

    debuggerState.switchToIsolate(null);
    debuggerState.dispose();
  }

  void _populateFromIsolate(Isolate isolate) async {
    final ScriptList scriptList =
        await serviceManager.service.getScripts(isolate.id);
    final List<ScriptRef> scripts = scriptList.scripts.toList();

    debuggerState.scripts = scripts;

    debuggerState.setRootLib(isolate.rootLib);
    debuggerState.updateFrom(isolate);

    final bool isRunning = isolate.pauseEvent == null ||
        isolate.pauseEvent.kind == EventKind.kResume;

    scriptsView.showScripts(
      scripts,
      debuggerState.rootLib.uri,
      debuggerState.commonScriptPrefix,
      selectRootScript: isRunning,
    );
  }

  void _displaySource(Script script) {
    if (script == null) {
      _sourcePathDiv.setInnerHtml('&nbsp;');
      sourceEditor.displayScript(script);
    } else {
      _sourcePathDiv.text = script.uri;
      sourceEditor.displayScript(script);
    }
  }

  Future<String> _retrieveFullStringValue(InstanceRef stringRef) async {
    if (stringRef.valueAsStringIsTruncated != true) {
      return stringRef.valueAsString;
    }

    final dynamic result = await serviceManager.service.getObject(
        debuggerState.isolateRef.id, stringRef.id,
        offset: 0, count: stringRef.length);
    if (result is Instance) {
      final Instance obj = result;
      return obj.valueAsString;
    } else {
      return '${stringRef.valueAsString}...';
    }
  }
}

class DebuggerState {
  VmService _service;

  StreamSubscription<Event> _debugSubscription;

  IsolateRef isolateRef;
  List<ScriptRef> scripts;

  final Map<String, Script> _scriptCache = <String, Script>{};

  final BehaviorSubject<bool> _paused = BehaviorSubject<bool>(seedValue: false);
  final BehaviorSubject<bool> _supportsStepping =
      BehaviorSubject<bool>(seedValue: false);

  Event _lastEvent;

  final BehaviorSubject<List<Breakpoint>> _breakpoints =
      BehaviorSubject<List<Breakpoint>>(seedValue: <Breakpoint>[]);

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
        _lastEvent = isolate.pauseEvent;
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
    // Handle async suspensions; issue StepOption.kOverAsyncSuspension.
    final bool useAsyncStepping = _lastEvent?.atAsyncSuspension == true;
    return _service.resume(isolateRef.id,
        step: useAsyncStepping
            ? StepOption.kOverAsyncSuspension
            : StepOption.kOver);
  }

  Future<Success> stepIn() =>
      _service.resume(isolateRef.id, step: StepOption.kInto);

  Future<Success> stepOut() =>
      _service.resume(isolateRef.id, step: StepOption.kOut);

  @visibleForTesting
  Future<void> clearBreakpoints() async {
    final List<Breakpoint> breakpoints = _breakpoints.value.toList();
    await Future.forEach(breakpoints, (Breakpoint breakpoint) {
      return removeBreakpoint(breakpoint);
    });
  }

  Future<void> addBreakpoint(String scriptId, int line) {
    return _service.addBreakpoint(isolateRef.id, scriptId, line);
  }

  @visibleForTesting
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
    _lastEvent = event;

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
    _lastEvent = null;
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

class SourcePosition {
  SourcePosition(this.line, [this.column]);

  final int line;
  final int column;

  @override
  String toString() => '$line $column';
}

class SourceEditor {
  SourceEditor(this.codeMirror, this.debuggerState) {
    codeMirror.onGutterClick.listen((int line) {
      final List<Breakpoint> lineBps = linesToBreakpoints[line];

      if (lineBps == null || lineBps.isEmpty) {
        debuggerState.addBreakpoint(currentScript.id, line + 1).catchError((_) {
          // ignore
        });
      } else {
        final Breakpoint bp = lineBps.removeAt(0);
        debuggerState.removeBreakpoint(bp).catchError((_) {
          // ignore
        });
      }
    });
  }

  final CodeMirror codeMirror;
  final DebuggerState debuggerState;

  Script currentScript;
  ScriptAndPosition executionPoint;
  List<Breakpoint> breakpoints = <Breakpoint>[];
  Map<int, List<Breakpoint>> linesToBreakpoints = <int, List<Breakpoint>>{};
  int _currentLineClass;
  CoreElement _executionPointElement;

  void setBreakpoints(List<Breakpoint> breakpoints) {
    this.breakpoints = breakpoints;

    _refreshMarkers();
  }

  void _refreshMarkers() {
    // TODO(devoncarew): only change these if the breakpoints changed or the
    // script did
    codeMirror.clearGutter('breakpoints');
    linesToBreakpoints.clear();

    if (currentScript == null) {
      return;
    }

    for (Breakpoint breakpoint in breakpoints) {
      if (breakpoint.location is SourceLocation) {
        final SourceLocation loc = breakpoint.location;

        if (loc.script.id != currentScript.id) {
          continue;
        }

        final SourcePosition pos =
            debuggerState.calculatePosition(currentScript, loc.tokenPos);
        final int line = pos.line - 1;
        final List<Breakpoint> lineBps =
            linesToBreakpoints.putIfAbsent(line, () => <Breakpoint>[]);

        lineBps.add(breakpoint);

        codeMirror.setGutterMarker(
          line,
          'breakpoints',
          span(c: 'octicon octicon-primitive-dot').element,
        );
      } else if (breakpoint.location is UnresolvedSourceLocation) {
        final UnresolvedSourceLocation loc = breakpoint.location;

        if (loc.script.id != currentScript.id) {
          continue;
        }

        final int line = loc.line - 1;
        final List<Breakpoint> lineBps =
            linesToBreakpoints.putIfAbsent(line, () => <Breakpoint>[]);

        lineBps.add(breakpoint);

        codeMirror.setGutterMarker(
          line,
          'breakpoints',
          span(c: 'octicon octicon-primitive-dot').element,
        );
      }
    }

    if (executionPoint != null && executionPoint.matches(currentScript)) {
      if (executionPoint.position != null) {
        _showLineClass(executionPoint.position.line - 1);
      }
    }
  }

  void _clearLineClass() {
    if (_currentLineClass != null) {
      codeMirror.removeLineClass(
          _currentLineClass, 'background', 'executionLine');
      _currentLineClass = null;
    }

    _executionPointElement?.dispose();
    _executionPointElement = null;
  }

  void _showLineClass(int line) {
    if (_currentLineClass == line) {
      return;
    }

    _clearLineClass();
    _currentLineClass = line;
    codeMirror.addLineClass(_currentLineClass, 'background', 'executionLine');
  }

  void displayExecutionPoint(Script script, {SourcePosition position}) {
    executionPoint = ScriptAndPosition(script, position: position);

    // This also calls _refreshMarkers().
    displayScript(script, scrollTo: position);

    _executionPointElement?.dispose();
    _executionPointElement = null;

    if (script.source != null && position != null) {
      _executionPointElement =
          span(c: 'octicon octicon-arrow-up execution-marker');

      codeMirror.addWidget(
        Position(position.line - 1, position.column - 1),
        _executionPointElement.element,
      );
    }
  }

  void clearExecutionPoint() {
    executionPoint = null;
    _clearLineClass();
    _refreshMarkers();
  }

  final Map<String, int> _lastScrollPositions = <String, int>{};

  void displayScript(Script newScript, {SourcePosition scrollTo}) {
    if (currentScript != null) {
      final ScrollInfo scrollInfo = codeMirror.getScrollInfo();
      _lastScrollPositions[currentScript.uri] = scrollInfo.top;
    }

    final bool sameScript = currentScript?.uri == newScript?.uri;

    currentScript = newScript;

    if (newScript == null) {
      codeMirror.getDoc().setValue('');
    } else {
      // TODO(devoncarew): set the mode to either dart or javascript
      // codeMirror.setMode(mode);

      if (!sameScript) {
        final String source = newScript?.source ?? '<source not available>';
        codeMirror.getDoc().setValue(source);
      }

      if (scrollTo != null) {
        codeMirror.scrollIntoView(scrollTo.line - 1, 0, margin: 150);
      } else {
        final int top = _lastScrollPositions[newScript.uri] ?? 0;
        codeMirror.scrollTo(0, top);
      }
    }

    _executionPointElement?.dispose();
    _executionPointElement = null;

    _refreshMarkers();
  }
}

typedef URIDescriber = String Function(String uri);

class BreakpointsView implements CoreElementView {
  BreakpointsView(this._breakpointsCountDiv, DebuggerState debuggerState,
      URIDescriber uriDescriber) {
    _items = SelectableList<Breakpoint>()
      ..flex()
      ..clazz('menu-item-bottom-border')
      ..clazz('debugger-items-list');

    _items.setRenderer((Breakpoint breakpoint) {
      final dynamic location = breakpoint.location;

      final CoreElement element = li(c: 'list-item');

      if (location is UnresolvedSourceLocation) {
        element.text = uriDescriber(location.script.uri);
        element.add(span(text: ' line ${location.line}', c: 'subtle'));
      } else if (location is SourceLocation) {
        element.text = uriDescriber(location.script.uri);

        // Modify the rendering slightly asynchronously.
        debuggerState.getScript(location.script).then((Script script) {
          final SourcePosition pos =
              debuggerState.calculatePosition(script, location.tokenPos);
          element.add(span(text: ' line ${pos.line}', c: 'subtle'));
        });
      }

      if (!breakpoint.resolved) {
        element.add(span(text: ' (unresolved)', c: 'subtle'));
      }

      return element;
    });
  }

  final CoreElement _breakpointsCountDiv;

  SelectableList<Breakpoint> _items;

  Stream<Breakpoint> get onDoubleClick => _items.onDoubleClick;

  @override
  CoreElement get element => _items;

  Stream<Breakpoint> get onSelectionChanged => _items.onSelectionChanged;

  void showBreakpoints(List<Breakpoint> breakpoints) {
    breakpoints = breakpoints.toList();
    breakpoints.sort(_breakpointComparator);

    _items.setItems(breakpoints);
    _breakpointsCountDiv.text = breakpoints.length.toString();
  }
}

class ScriptsView implements CoreElementView {
  ScriptsView(URIDescriber uriDescriber) {
    _items = SelectableList<ScriptRef>()
      ..flex()
      ..clazz('debugger-items-list');
    _items.setRenderer((ScriptRef scriptRef) {
      final String uri = scriptRef.uri;
      final String name = uriDescriber(uri);
      final CoreElement element = li(text: name, c: 'list-item');
      if (name != uri) {
        element.add(span(text: ' $uri', c: 'subtle'));
      }
      element.tooltip = uri;
      return element;
    });
  }

  SelectableList<ScriptRef> _items;

  String rootLib;

  List<ScriptRef> get items => _items.items;

  @override
  CoreElement get element => _items;

  Stream<ScriptRef> get onSelectionChanged => _items.onSelectionChanged;

  Stream<void> get onScriptsChanged => _items.onItemsChanged;

  void showScripts(
    List<ScriptRef> scripts,
    String rootLib,
    String commonPrefix, {
    bool selectRootScript = false,
  }) {
    this.rootLib = rootLib;

    scripts.sort((ScriptRef ref1, ScriptRef ref2) {
      String uri1 = ref1.uri;
      String uri2 = ref2.uri;

      uri1 = _convertDartInternalUris(uri1);
      uri2 = _convertDartInternalUris(uri2);

      if (commonPrefix != null) {
        if (uri1.startsWith(commonPrefix) && !uri2.startsWith(commonPrefix)) {
          return -1;
        } else if (!uri1.startsWith(commonPrefix) &&
            uri2.startsWith(commonPrefix)) {
          return 1;
        }
      }

      if (uri1.startsWith('dart:') && !uri2.startsWith('dart:')) {
        return 1;
      } else if (!uri1.startsWith('dart:') && uri2.startsWith('dart:')) {
        return -1;
      }

      return uri1.compareTo(uri2);
    });

    ScriptRef selection;
    if (selectRootScript) {
      selection = scripts.firstWhere((script) => script.uri == rootLib,
          orElse: () => null);
    }
    _items.setItems(scripts, selection: selection);
  }

  String _convertDartInternalUris(String uri) {
    if (uri.startsWith('dart:_')) {
      return uri.replaceAll('dart:_', 'dart:');
    } else {
      return uri;
    }
  }

  void clearScripts() => _items.clearItems();
}

class CallStackView implements CoreElementView {
  CallStackView() {
    _items = SelectableList<Frame>()
      ..flex()
      ..clazz('menu-item-bottom-border')
      ..clazz('debugger-items-list');

    _items.setRenderer((Frame frame) {
      String name = frame.code?.name ?? '<none>';
      if (name.startsWith('[Unoptimized] ')) {
        name = name.substring('[Unoptimized] '.length);
      }
      name = name.replaceAll('<anonymous closure>', '<closure>');

      String locationDescription;
      if (frame.kind == FrameKind.kAsyncSuspensionMarker) {
        name = '<async break>';
      } else if (frame.kind != emptyStackMarker) {
        locationDescription = frame.location.script.uri;

        if (locationDescription.contains('/')) {
          locationDescription = locationDescription
              .substring(locationDescription.lastIndexOf('/') + 1);
        }
      }

      final CoreElement element = li(text: name, c: 'list-item');
      if (frame.kind == FrameKind.kAsyncSuspensionMarker ||
          frame.kind == emptyStackMarker) {
        element.toggleClass('subtle');
      }
      if (locationDescription != null) {
        element.add(span(text: ' $locationDescription', c: 'subtle'));
      }
      return element;
    });
  }

  static const String emptyStackMarker = 'EmptyStackMarker';

  SelectableList<Frame> _items;

  List<Frame> get items => _items.items;

  @override
  CoreElement get element => _items;

  Stream<Frame> get onSelectionChanged => _items.onSelectionChanged;

  void showFrames(List<Frame> frames, {bool selectTop = false}) {
    if (frames.isEmpty) {
      // Create a marker frame for 'no call frames'.
      final Frame frame = Frame()
        ..kind = emptyStackMarker
        ..code = (CodeRef()..name = '<no call frames>');
      _items.setItems([frame]);
    } else {
      _items.setItems(frames, selection: frames.isEmpty ? null : frames.first);
    }
  }

  void clearFrames() {
    _items.setItems(<Frame>[]);
  }
}

typedef VariableDescriber = Future<String> Function(BoundVariable variable);

class VariablesView implements CoreElementView {
  VariablesView(VariableDescriber variableDescriber) {
    _items = SelectableList<BoundVariable>()
      ..flex()
      ..clazz('menu-item-bottom-border')
      ..clazz('debugger-items-list');
    _items.canDeselect = true;

    _items.setRenderer((BoundVariable variable) {
      final String name = variable.name;
      final dynamic value = variable.value;
      String valueStr;
      if (value is InstanceRef) {
        if (value.valueAsString == null) {
          // TODO(devoncarew): also show an expandable toggle
          valueStr = value.classRef.name;
        } else {
          valueStr = value.valueAsString;
          if (value.valueAsStringIsTruncated) {
            valueStr += '...';
          }
          if (value.kind == InstanceKind.kString) {
            valueStr = "'$valueStr'";
          }
        }
      } else if (value is Sentinel) {
        valueStr = value.valueAsString;
      } else if (value is TypeArgumentsRef) {
        valueStr = value.name;
      } else {
        valueStr = value.toString();
      }

      final CoreElement element = li(
        text: name,
        c: 'list-item',
      )..add(span(text: ' $valueStr', c: 'subtle'));

      StreamSubscription sub;

      sub = element.element.onMouseOver.listen((e) {
        // TODO(devoncarew): Call toString() only after a short dwell.
        sub.cancel();
        variableDescriber(variable).then((String desc) {
          element.tooltip = desc;
        });
      });

      return element;
    });
  }

  SelectableList<BoundVariable> _items;

  List<BoundVariable> get items => _items.items;

  @override
  CoreElement get element => _items;

  void showVariables(Frame frame) {
    // AsyncCausal frames don't have local vars.
    _items.setItems(frame.vars ?? <BoundVariable>[]);
  }

  void clearVariables() {
    _items.setItems(<BoundVariable>[]);
  }
}

class BreakOnExceptionControl extends CoreElement {
  BreakOnExceptionControl()
      : super('div', classes: 'break-on-exceptions margin-left flex-no-wrap') {
    final CoreElement unhandled = CoreElement('input')
      ..setAttribute('type', 'checkbox');
    _unhandledElement = unhandled.element;

    final CoreElement all = CoreElement('input')
      ..setAttribute('type', 'checkbox');
    _allElement = all.element;

    add([
      CoreElement('label')
        ..add(<CoreElement>[
          unhandled,
          span(text: ' Break on unhandled exceptions')
        ]),
      CoreElement('label')
        ..add(<CoreElement>[
          all,
          span(text: ' Break on all exceptions'),
        ]),
    ]);

    unhandled.element.onChange.listen((_) {
      _pauseModeController.add(exceptionPauseMode);
    });

    all.element.onChange.listen((_) {
      if (_allElement.checked) {
        unhandled.enabled = false;
        _unhandledElement.checked = true;
      } else {
        unhandled.enabled = true;
      }
      _pauseModeController.add(exceptionPauseMode);
    });
  }

  html.InputElement _unhandledElement;
  html.InputElement _allElement;

  final StreamController<String> _pauseModeController =
      StreamController.broadcast();

  /// See the string values for [ExceptionPauseMode].
  Stream<String> get onPauseModeChanged => _pauseModeController.stream;

  String get exceptionPauseMode {
    if (_allElement.checked) {
      return ExceptionPauseMode.kAll;
    } else if (_unhandledElement.checked) {
      return ExceptionPauseMode.kUnhandled;
    } else {
      return ExceptionPauseMode.kNone;
    }
  }

  set exceptionPauseMode(final String value) {
    if (value == ExceptionPauseMode.kAll) {
      _allElement.checked = true;
      _unhandledElement.checked = true;
      _unhandledElement.setAttribute('disabled', '');
    } else if (value == ExceptionPauseMode.kUnhandled) {
      _allElement.checked = false;
      _unhandledElement.checked = true;
      _unhandledElement.attributes.remove('disabled');
    } else {
      _allElement.checked = false;
      _unhandledElement.checked = false;
      _unhandledElement.attributes.remove('disabled');
    }
  }
}

class ScriptAndPosition {
  ScriptAndPosition(this.script, {@required this.position});

  final Script script;
  final SourcePosition position;

  String get uri => script.uri;

  bool matches(Script script) => uri == script.uri;
}

int _breakpointComparator(Breakpoint a, Breakpoint b) {
  ScriptRef getRef(dynamic location) {
    if (location is SourceLocation) {
      return location.script;
    } else if (location is UnresolvedSourceLocation) {
      return location.script;
    } else {
      return null;
    }
  }

  int getPos(dynamic location) {
    if (location is SourceLocation) {
      return location.tokenPos ?? 0;
    } else if (location is UnresolvedSourceLocation) {
      return location.line ?? 0;
    } else {
      return 0;
    }
  }

  // sort by script
  final ScriptRef aRef = getRef(a.location);
  final ScriptRef bRef = getRef(b.location);
  final int compare = aRef.uri.compareTo(bRef.uri);
  if (compare != 0) {
    return compare;
  }

  // then sort by location
  return getPos(a.location) - getPos(b.location);
}

class ConsoleArea implements CoreElementView {
  ConsoleArea() {
    final Map<String, dynamic> options = <String, dynamic>{
      'mode': 'text/plain',
    };

    _container = div()
      ..layoutVertical()
      ..flex();
    _editor = CodeMirror.fromElement(_container.element, options: options);
    _editor.setReadOnly(true);

    final codeMirrorElement = _container.element.children[0];
    codeMirrorElement.setAttribute('flex', '');
  }

  final DelayedTimer _timer = DelayedTimer(
      const Duration(milliseconds: 100), const Duration(seconds: 1));
  final StringBuffer _bufferedText = StringBuffer();

  CoreElement _container;
  CodeMirror _editor;

  @override
  CoreElement get element => _container;

  void refresh() => _editor.refresh();

  void appendText(String text) {
    // We delay writes here to batch up calls to editor.replaceRange().
    _bufferedText.write(text);

    _timer.invoke(() {
      final String string = _bufferedText.toString();
      _bufferedText.clear();
      _append(string);
    });
  }

  void _append(String text) {
    // append text
    _editor
        .getDoc()
        .replaceRange(text, Position(_editor.getDoc().lastLine() + 1, 0));

    // scroll to end
    final int lastLineIndex = _editor.getDoc().lastLine();
    final String lastLine = _editor.getDoc().getLine(lastLineIndex);
    _editor.scrollIntoView(lastLineIndex, lastLine.length);
  }

  @visibleForTesting
  String getContents() {
    return _editor.getDoc().getValue();
  }
}
