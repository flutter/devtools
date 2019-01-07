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

// TODO(devoncarew): allow browsing object fields

// TODO(devoncarew): improve selection behavior in the left nav area

// TODO(devoncarew): have the console area be collapsible

// TODO(devoncarew): handle cases of isolates terminating and new isolates
// replacing them (flutter hot restart)

// TODO(devoncarew): show toasts for some events (new isolate creation)

// TODO(devoncarew): handle displaying lists and maps in the variables view

// TODO(devoncarew): handle displaying large lists, maps, in the variable view

class DebuggerScreen extends Screen {
  DebuggerScreen()
      : debuggerState = new DebuggerState(),
        super(name: 'Debugger', id: 'debugger', iconClass: 'octicon-bug') {
    deviceStatus = new StatusItem();
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
  void createContent(Framework framework, CoreElement mainDiv) {
    CoreElement sourceArea;

    final PButton resumeButton = new PButton(null)
      ..primary()
      ..small()
      ..id = 'resume-button'
      ..add(<CoreElement>[
        span(c: 'octicon octicon-triangle-right'),
        span(text: 'Resume'),
      ]);

    resumeButton.click(() async {
      resumeButton.disabled = true;
      await debuggerState.resume();
      resumeButton.disabled = false;
    });

    debuggerState.onPausedChanged.listen((bool isPaused) {
      resumeButton.disabled = !isPaused;
    });

    PButton stepOver, stepIn, stepOut;

    final BreakOnExceptionControl breakOnExceptionControl =
        new BreakOnExceptionControl();
    breakOnExceptionControl.onPauseModeChanged.listen((String mode) {
      debuggerState.setExceptionPauseMode(mode);
    });
    debuggerState.onExceptionPauseModeChanged.listen((String mode) {
      breakOnExceptionControl.exceptionPauseMode = mode;
    });

    consoleArea = new ConsoleArea();
    List<CoreElement> panels;

    mainDiv.add(<CoreElement>[
      div(c: 'section')
        ..flex()
        ..layoutHorizontal()
        ..add(panels = <CoreElement>[
          div(c: 'debugger-menu')
            ..layoutVertical()
            ..add(<CoreElement>[
              _buildMenuNav(),
            ]),
          div()
            ..element.style.overflowX = 'hidden'
            ..layoutVertical()
            ..flex()
            ..add(<CoreElement>[
              div(c: 'section')
                ..layoutHorizontal()
                ..add(<CoreElement>[
                  resumeButton,
                  div(c: 'btn-group margin-left')
                    ..add(<CoreElement>[
                      stepIn = new PButton(null)
                        ..add(<CoreElement>[
                          span(c: 'octicon octicon-chevron-down'),
                          span(text: 'Step in'),
                        ])
                        ..small(),
                      stepOver = new PButton(null)
                        ..add(<CoreElement>[
                          span(c: 'octicon octicon-chevron-right'),
                          span(text: 'Step over'),
                        ])
                        ..small(),
                      stepOut = new PButton(null)
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
                ..flex()
                ..layoutVertical()
                ..add(<CoreElement>[
                  _sourcePathDiv = div(c: 'source-head'),
                ]),
              div(c: 'section table-border secondary-area')
                ..layoutVertical()
                ..add(consoleArea.element),
            ]),
        ]),
    ]);

    _sourcePathDiv.setInnerHtml('&nbsp;');

    split.flexSplit(
      panels,
      gutterSize: 12,
      sizes: [25, 75],
      minSize: [150, 200],
    );

    debuggerState.onSupportsStepping.listen((bool value) {
      stepOver.enabled = value;
      stepIn.enabled = value;
      stepOut.enabled = value;
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
        new CodeMirror.fromElement(sourceArea.element, options: options);
    codeMirror.setReadOnly(true);
    final codeMirrorElement = _sourcePathDiv.element.parent.children[1];
    codeMirrorElement.setAttribute('flex', '');

    sourceEditor = new SourceEditor(codeMirror, debuggerState);

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

          final Frame newFrame = new Frame()
            ..type = frame.type
            ..index = frame.index
            ..function = frame.function
            ..code = frame.code
            ..location = frame.location
            ..kind = frame.kind;

          final List<BoundVariable> newVars = <BoundVariable>[];
          newVars.add(new BoundVariable()
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
  }

  @override
  void entering() {
    if (!_initialized) {
      _initialize();
    }
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
    callStackView = new CallStackView();

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
    variablesView = new VariablesView(describer);

    _breakpointsCountDiv = span(text: '0', c: 'counter');
    breakpointsView = new BreakpointsView(
        _breakpointsCountDiv, debuggerState, debuggerState.getShortScriptName);
    breakpointsView.onDoubleClick.listen((Breakpoint breakpoint) async {
      final dynamic location = breakpoint.location;
      if (location is SourceLocation) {
        final Script script = await debuggerState.getScript(location.script);
        final SourcePosition pos =
            debuggerState.calculatePosition(script, location.tokenPos);
        sourceEditor.displayScript(script,
            scrollTo: new SourcePosition(pos.line - 1));
      } else if (location is UnresolvedSourceLocation) {
        final Script script = await debuggerState.getScript(location.script);
        sourceEditor.displayScript(script,
            scrollTo: new SourcePosition(location.line - 1));
      }
    });

    CoreElement scriptCountDiv;
    scriptsView = new ScriptsView(debuggerState.getShortScriptName);
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

    final PNavMenu menu = new PNavMenu(<CoreElement>[
      new PNavMenuItem('Call stack')
        ..click(() => callStackView.element.toggleAttribute('hidden')),
      callStackView.element,
      new PNavMenuItem('Variables')
        ..click(() => variablesView.element.toggleAttribute('hidden')),
      variablesView.element,
      new PNavMenuItem('Breakpoints')
        ..add(_breakpointsCountDiv)
        ..click(() => breakpointsView.element.toggleAttribute('hidden')),
      breakpointsView.element,
      new PNavMenuItem('Scripts')
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

    deviceStatus.element.text =
        '${serviceManager.vm.targetCPU} ${serviceManager.vm.architectureBits}-bit';

    service.onStdoutEvent.listen((Event e) {
      final String message = decodeBase64(e.bytes);
      consoleArea.append(message);
    });

    service.onStderrEvent.listen((Event e) {
      final String message = decodeBase64(e.bytes);
      consoleArea.append(message, isError: true);
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

  @override
  HelpInfo get helpInfo => null;

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

  final BehaviorSubject<bool> _paused =
      new BehaviorSubject<bool>(seedValue: false);
  final BehaviorSubject<bool> _supportsStepping =
      new BehaviorSubject<bool>(seedValue: false);

  Event _lastEvent;

  final BehaviorSubject<List<Breakpoint>> _breakpoints =
      new BehaviorSubject<List<Breakpoint>>(seedValue: <Breakpoint>[]);

  final BehaviorSubject<String> _exceptionPauseMode = new BehaviorSubject();

  InstanceRef _reportedException;

  bool get isPaused => _paused.value;

  Stream<bool> get onPausedChanged => _paused;

  Stream<bool> get onSupportsStepping =>
      new Observable<bool>.concat(<Stream<bool>>[_paused, _supportsStepping]);

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
          return new SourcePosition(line, row.elementAt(index + 1));
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
        debuggerState.addBreakpoint(currentScript.id, line + 1);
      } else {
        final Breakpoint bp = lineBps.removeAt(0);
        debuggerState.removeBreakpoint(bp);
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
    codeMirror.clearGutter('breakpoints');
    //_clearLineClass();
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
    }
    _currentLineClass = null;

    _executionPointElement?.dispose();
    _executionPointElement = null;
  }

  void _showLineClass(int line) {
    if (_currentLineClass != null) {
      _clearLineClass();
    }
    _currentLineClass = line;
    codeMirror.addLineClass(_currentLineClass, 'background', 'executionLine');
  }

  void displayExecutionPoint(Script script, {SourcePosition position}) {
    executionPoint = new ScriptAndPosition(script.uri, position: position);

    // This also calls _refreshMarkers().
    displayScript(script, scrollTo: position);

    _executionPointElement?.dispose();
    _executionPointElement = null;

    if (script.source != null && position != null) {
      _executionPointElement =
          span(c: 'octicon octicon-arrow-up execution-marker');

      codeMirror.addWidget(
        new Position(position.line - 1, position.column - 1),
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

class BreakpointsView {
  BreakpointsView(this._breakpointsCountDiv, DebuggerState debuggerState,
      URIDescriber uriDescriber) {
    _items = new SelectableList<Breakpoint>()
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

  CoreElement get element => _items;

  Stream<Breakpoint> get onSelectionChanged => _items.onSelectionChanged;

  void showBreakpoints(List<Breakpoint> breakpoints) {
    breakpoints = breakpoints.toList();
    breakpoints.sort(_breakpointComparator);

    _items.setItems(breakpoints);
    _breakpointsCountDiv.text = breakpoints.length.toString();
  }
}

class ScriptsView {
  ScriptsView(URIDescriber uriDescriber) {
    _items = new SelectableList<ScriptRef>()
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

class CallStackView {
  CallStackView() {
    _items = new SelectableList<Frame>()
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
      } else {
        locationDescription = frame.location.script.uri;

        if (locationDescription.contains('/')) {
          locationDescription = locationDescription
              .substring(locationDescription.lastIndexOf('/') + 1);
        }
      }

      final CoreElement element = li(text: name, c: 'list-item');
      if (frame.kind == FrameKind.kAsyncSuspensionMarker) {
        element.toggleClass('subtle');
      }
      if (locationDescription != null) {
        element.add(span(text: ' $locationDescription', c: 'subtle'));
      }
      return element;
    });
  }

  SelectableList<Frame> _items;

  List<Frame> get items => _items.items;

  CoreElement get element => _items;

  Stream<Frame> get onSelectionChanged => _items.onSelectionChanged;

  void showFrames(List<Frame> frames, {bool selectTop = false}) {
    _items.setItems(frames, selection: frames.isEmpty ? null : frames.first);
  }

  void clearFrames() {
    _items.setItems(<Frame>[]);
  }
}

typedef VariableDescriber = Future<String> Function(BoundVariable variable);

class VariablesView {
  VariablesView(VariableDescriber variableDescriber) {
    _items = new SelectableList<BoundVariable>()
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
  BreakOnExceptionControl() : super('div', classes: 'break-on-exceptions') {
    final CoreElement unhandled = new CoreElement('input')
      ..setAttribute('type', 'checkbox');
    _unhandledElement = unhandled.element;

    final CoreElement all = new CoreElement('input')
      ..setAttribute('type', 'checkbox');
    _allElement = all.element;

    add([
      span(text: 'Break on: '),
      new CoreElement('label')
        ..add(<CoreElement>[unhandled, span(text: ' Unhandled exceptions')]),
      new CoreElement('label')
        ..add(<CoreElement>[all, span(text: ' All exceptions')]),
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
      new StreamController.broadcast();

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
  ScriptAndPosition(this.uri, {@required this.position});

  final String uri;
  final SourcePosition position;

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

class ConsoleArea {
  ConsoleArea() {
    final Map<String, dynamic> options = <String, dynamic>{
      'mode': 'text/plain',
    };

    _container = div()
      ..layoutVertical()
      ..flex();
    _editor = new CodeMirror.fromElement(_container.element, options: options);
    _editor.setReadOnly(true);

    final codeMirrorElement = _container.element.children[0];
    codeMirrorElement.setAttribute('flex', '');
  }

  CoreElement _container;
  CodeMirror _editor;

  CoreElement get element => _container;

  void refresh() => _editor.refresh();

  void append(String text, {bool isError = false}) {
    // append text
    _editor
        .getDoc()
        .replaceRange(text, Position(_editor.getDoc().lastLine() + 1, 0));

    // TODO(devoncarew): Display stderr text (isError) with a different style.

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
