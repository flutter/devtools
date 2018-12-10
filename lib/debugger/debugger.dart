// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:js' show JsObject;

import 'package:codemirror/codemirror.dart';
import 'package:rxdart/rxdart.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import '../framework/framework.dart';
import '../globals.dart';
import '../ui/custom.dart';
import '../ui/elements.dart';
import '../ui/primer.dart';

// TODO: if a value is selected, show the toString result somewhere

// TODO: allow browsing object fields

// TODO: improve selection in the nav area

// TODO: handle double click on breakpoints

// TODO: handle break on exceptions

class DebuggerScreen extends Screen {
  DebuggerScreen()
      : super(name: 'Debugger', id: 'debugger', iconClass: 'octicon-bug') {
    deviceStatus = new StatusItem();
    addStatusItem(deviceStatus);

    serviceInfo.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceInfo.hasConnection) {
      _handleConnectionStart(serviceInfo.service);
    }
    serviceInfo.isolateManager.onSelectedIsolateChanged
        .listen(_handleIsolateChanged);
    serviceInfo.onConnectionClosed.listen(_handleConnectionStop);
  }

  StatusItem deviceStatus;

  SelectableList<ScriptRef> _scriptItems;
  CoreElement _breakpointsCountDiv;
  CoreElement _scriptCountDiv;
  CoreElement _sourcePathDiv;

  SourceEditor sourceEditor;
  DebuggerState debuggerState;
  CallStackView callStackView;
  VariablesView variablesView;
  BreakpointsView breakpointsView;

  @override
  void createContent(Framework framework, CoreElement mainDiv) {
    CoreElement sourceArea;

    debuggerState = new DebuggerState();

    final PButton resumeButton = new PButton(null)
      ..primary()
      ..small()
      ..element.style.minWidth = '90px'
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

    mainDiv.add(<CoreElement>[
      div(c: 'section')
        ..flex()
        ..layoutHorizontal()
        ..add(<CoreElement>[
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
                  //new PButton('Foo bar')..small(),
                ]),
              sourceArea = div(c: 'section table-border')
                ..flex()
                ..layoutVertical()
                ..add(<CoreElement>[
                  _sourcePathDiv = div(c: 'source-head'),
                ]),
              //div(c: 'section secondary-area', text: 'Console output'),
            ]),
        ]),
    ]);

    _sourcePathDiv.setInnerHtml('&nbsp;');

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
    // ignore: always_specify_types
    final codeMirrorElement = _sourcePathDiv.element.parent.children[1];
    codeMirrorElement.setAttribute('flex', '');

    sourceEditor = new SourceEditor(codeMirror, debuggerState);

    debuggerState.onBreakpointsChanged
        .listen((List<Breakpoint> breakpoints) async {
      sourceEditor.setBreakpoints(breakpoints);
    });

    debuggerState.onPausedChanged.listen((bool paused) async {
      if (paused) {
        // todo: use async frames
        final Stack stack = await debuggerState.getStack();
        callStackView.showFrames(stack, selectTop: true);
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
        final ScriptRef scriptRef = location.script;
        final Script script = await debuggerState.getScript(scriptRef);
        final Pos position =
            debuggerState.calculatePosition(script, location.tokenPos);

        _sourcePathDiv.text = script.uri;
        sourceEditor.displayExecutionPoint(script, position);

        variablesView.showVariables(frame);
      }
    });
  }

  CoreElement _buildMenuNav() {
    callStackView = new CallStackView();
    variablesView = new VariablesView();

    _breakpointsCountDiv = span(text: '0', c: 'counter');
    breakpointsView = new BreakpointsView(debuggerState, _breakpointsCountDiv);
    breakpointsView.onDoubleClick.listen((Breakpoint breakpoint) async {
      final dynamic location = breakpoint.location;
      if (location is SourceLocation) {
        final Script script = await debuggerState.getScript(location.script);
        final Pos pos =
            debuggerState.calculatePosition(script, location.tokenPos);
        sourceEditor.displayScript(script, scrollTo: new Pos(pos.line - 1));
      } else if (location is UnresolvedSourceLocation) {
        final Script script = await debuggerState.getScript(location.script);
        sourceEditor.displayScript(script,
            scrollTo: new Pos(location.line - 1));
      }
    });

    _scriptItems = new SelectableList<ScriptRef>()
      ..flex()
      ..hidden(true)
      ..element.style.overflowY = 'scroll';

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
          _scriptCountDiv = span(text: '0', c: 'counter'),
        )
        ..click(() => _scriptItems.toggleAttribute('hidden')),
      _scriptItems,
    ], supportsSelection: false)
      ..flex()
      ..layoutVertical();

    _scriptItems.onSelectionChanged.listen((ScriptRef scriptRef) async {
      if (scriptRef == null) {
        _displaySource(null);
        return;
      }

      final IsolateRef isolateRef = serviceInfo.isolateManager.selectedIsolate;
      final dynamic result =
          await serviceInfo.service.getObject(isolateRef.id, scriptRef.id);

      if (result is Script) {
        _displaySource(result);
      } else {
        _displaySource(null);
      }
    });

    // TODO: listen to selection changes, jump to the source location
    debuggerState.onBreakpointsChanged.listen((List<Breakpoint> breakpoints) {
      breakpointsView.showBreakpoints(breakpoints);
    });

    return menu;
  }

  void _handleConnectionStart(VmService service) {
//    extensionTracker = new ExtensionTracker(service);
//    extensionTracker.start();
//
//    extensionTracker.onChange.listen((_) {
//      framesChartStateMixin.setState(() {
//        if (extensionTracker.hasIsolateTargets && !visible) {
//          visible = true;
//        }
//
//        _rebuildTogglesDiv();
//      });
//    });

    // TODO: add listeners
    debuggerState.setVmService(serviceInfo.service);

    deviceStatus.element.text =
        '${serviceInfo.vm.targetCPU} ${serviceInfo.vm.architectureBits}-bit';
  }

  void _handleIsolateChanged(IsolateRef isolateRef) {
    if (isolateRef == null) {
      _scriptItems.clearItems();
      _scriptCountDiv.text = '0';

      debuggerState.switchToIsolate(isolateRef);

      return;
    }

    debuggerState.switchToIsolate(isolateRef);

    serviceInfo.service.getIsolate(isolateRef.id).then((dynamic result) {
      if (result is Isolate) {
        _populateFromIsolate(result);
      } else {
        _scriptItems.clearItems();
        _scriptCountDiv.text = '0';
      }
    }).catchError((dynamic e) {
      framework.showError('Error retrieving isolate information', e);
    });
  }

  void _handleConnectionStop(dynamic event) {
    deviceStatus.element.text = '';

    _scriptItems.clearItems();
    _scriptCountDiv.text = '0';

    debuggerState.switchToIsolate(null);
    debuggerState.dispose();
  }

  @override
  HelpInfo get helpInfo => null;

  void _populateFromIsolate(Isolate isolate) async {
    final ScriptList scriptList =
        await serviceInfo.service.getScripts(isolate.id);
    final List<ScriptRef> scripts = scriptList.scripts.toList();

    String scriptPrefix = isolate.rootLib.uri;
    if (scriptPrefix.contains('/lib/')) {
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
    } else if (scriptPrefix.contains('/example/')) {
      scriptPrefix =
          scriptPrefix.substring(0, scriptPrefix.lastIndexOf('/example/'));
      if (scriptPrefix.contains('/')) {
        scriptPrefix =
            scriptPrefix.substring(0, scriptPrefix.lastIndexOf('/') + 1);
      }
    } else {
      scriptPrefix = null;
    }

    debuggerState.setCommonPrefix(scriptPrefix);
    debuggerState.updateFrom(isolate);

    scripts.sort((ScriptRef ref1, ScriptRef ref2) {
      String uri1 = ref1.uri;
      String uri2 = ref2.uri;

      if (uri1.startsWith('dart:_')) {
        uri1 = uri1.replaceAll('dart:_', 'dart:');
      }
      if (uri2.startsWith('dart:_')) {
        uri2 = uri2.replaceAll('dart:_', 'dart:');
      }

      if (uri1.startsWith('dart:') && !uri2.startsWith('dart:')) {
        return 1;
      }
      if (!uri1.startsWith('dart:') && uri2.startsWith('dart:')) {
        return -1;
      }

      if (uri1.startsWith('package:') && !uri2.startsWith('package:')) {
        return 1;
      }
      if (!uri1.startsWith('package:') && uri2.startsWith('package:')) {
        return -1;
      }

      return uri1.compareTo(uri2);
    });

    _scriptItems.setRenderer((ScriptRef scriptRef) {
      final String uri = scriptRef.uri;
      final String name = debuggerState.getShortScriptName(uri);
      final CoreElement element = li(text: name, c: 'list-item');
      if (name != uri) {
        element.add(span(text: ' $uri', c: 'subtle'));
      }
      element.tooltip = uri;
      return element;
    });

    _scriptItems.setItems(scripts);
    _scriptCountDiv.text = scripts.length.toString();
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
}

class DebuggerState {
  DebuggerState();

  // TODO: handle EventKind.kIsolateReload

  VmService service;

  StreamSubscription<Event> _debugSubscription;

  IsolateRef isolateRef;

  final Map<String, Script> _scriptCache = <String, Script>{};

  final BehaviorSubject<bool> _paused =
      new BehaviorSubject<bool>(seedValue: false);
  final BehaviorSubject<bool> _stepping =
      new BehaviorSubject<bool>(seedValue: false);

  final BehaviorSubject<List<Breakpoint>> _breakpoints =
      new BehaviorSubject<List<Breakpoint>>(seedValue: <Breakpoint>[]);

  bool get isPaused => _paused.value;

  Stream<bool> get onPausedChanged => _paused;

  Stream<bool> get onSupportsStepping =>
      new Observable<bool>.concat(<Stream<bool>>[_paused, _stepping]);

  Stream<List<Breakpoint>> get onBreakpointsChanged => _breakpoints;

  void setVmService(VmService service) {
    this.service = service;

    _debugSubscription = service.onDebugEvent.listen(_handleIsolateEvent);
  }

  void switchToIsolate(IsolateRef ref) async {
    isolateRef = ref;

    _updatePaused(false);

    _clearCaches();

    if (ref == null) {
      _breakpoints.add(<Breakpoint>[]);
      return;
    }

    final dynamic result = await service.getIsolate(isolateRef.id);
    if (result is Isolate) {
      final Isolate isolate = result;

      if (isolate.pauseEvent != null &&
          isolate.pauseEvent.kind != EventKind.kResume) {
        _updatePaused(true);
      }

      _breakpoints.add(isolate.breakpoints);
    }
  }

  Future<void> pause() => service.pause(isolateRef.id);

  Future<void> resume() => service.resume(isolateRef.id);

  // TODO: handle async suspensions
  Future<void> stepOver() =>
      service.resume(isolateRef.id, step: StepOption.kOver);

  Future<void> stepIn() =>
      service.resume(isolateRef.id, step: StepOption.kInto);

  Future<void> stepOut() =>
      service.resume(isolateRef.id, step: StepOption.kOut);

  Future<void> addBreakpoint(String scriptId, int line) {
    return service.addBreakpoint(isolateRef.id, scriptId, line);
  }

  Future<void> removeBreakpoint(Breakpoint breakpoint) {
    return service.removeBreakpoint(isolateRef.id, breakpoint.id);
  }

  Future<Stack> getStack() {
    return service.getStack(isolateRef.id);
  }

  void _handleIsolateEvent(Event event) {
    if (event.isolate.id != isolateRef.id) {
      return;
    }

    _stepping.add(event.topFrame != null);

    print(event.kind);

    switch (event.kind) {
      case EventKind.kResume:
        _updatePaused(false);
        break;
      case EventKind.kPauseStart:
      case EventKind.kPauseExit:
      case EventKind.kPauseBreakpoint:
      case EventKind.kPauseInterrupted:
      case EventKind.kPauseException:
      case EventKind.kPausePostRequest:
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
          await service.getObject(isolateRef.id, scriptRef.id);
    }

    return _scriptCache[scriptRef.id];
  }

  Pos calculatePosition(Script script, int tokenPos) {
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
          return new Pos(line, row.elementAt(index + 1));
        }
        index += 2;
      }
    }

    return null;
  }

  String commonScriptPrefix;

  void setCommonPrefix(String commonScriptPrefix) {
    this.commonScriptPrefix = commonScriptPrefix;
  }

  String getShortScriptName(String uri) {
    if (commonScriptPrefix != null && uri.startsWith(commonScriptPrefix)) {
      return uri.substring(commonScriptPrefix.length);
    } else {
      return uri;
    }
  }

  void updateFrom(Isolate isolate) {
    _breakpoints.add(isolate.breakpoints);
  }
}

class Pos {
  Pos(this.line, [this.column]);

  final int line;
  final int column;

  @override
  String toString() => '$line $column';
}

class SourceEditor {
  SourceEditor(this.codeMirror, this.debuggerState) {
    codeMirror.onEvent('gutterClick', true).listen((dynamic line) {
      if (line is int) {
        final List<Breakpoint> lineBps = linesToBreakpoints[line];

        if (lineBps == null || lineBps.isEmpty) {
          debuggerState.addBreakpoint(currentScript.id, line + 1);
        } else {
          final Breakpoint bp = lineBps.removeAt(0);
          debuggerState.removeBreakpoint(bp);
        }
      }
    });
  }

  final CodeMirror codeMirror;
  final DebuggerState debuggerState;

  Script currentScript;
  ScriptAndPos executionPoint;
  List<Breakpoint> breakpoints = <Breakpoint>[];
  Map<int, List<Breakpoint>> linesToBreakpoints = <int, List<Breakpoint>>{};

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

        final Pos pos =
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
      _showLineClass(executionPoint.position.line - 1);
    }
  }

  int _currentLineClass;
  CoreElement _executionPointElement;

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

  void displayExecutionPoint(Script script, Pos position) {
    executionPoint = new ScriptAndPos(script.uri, position);

    // This also calls _refreshMarkers().
    displayScript(script, scrollTo: position);

    _executionPointElement?.dispose();

    if (script.source != null) {
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
    _refreshMarkers();
  }

  final Map<String, int> _lastScrollPositions = <String, int>{};

  void displayScript(Script newScript, {Pos scrollTo}) {
    if (currentScript != null) {
      final dynamic scrollInfo = codeMirror.call('getScrollInfo');
      _lastScrollPositions[currentScript.uri] = scrollInfo['top'];
    }

    final bool sameScript = currentScript?.uri == newScript?.uri;

    currentScript = newScript;

    if (newScript == null) {
      codeMirror.getDoc().setValue('');
    } else {
      // set the mode to either dart or javascript
      // codeMirror.setMode(mode);

      final String source = newScript?.source ?? '<source not available>';
      if (!sameScript) {
        codeMirror.getDoc().setValue(source);
      }

      if (scrollTo != null) {
        codeMirror.callArgs('scrollIntoView', <dynamic>[
          new JsObject.jsify(<String, int>{'line': scrollTo.line - 1, 'ch': 0}),
          150,
        ]);
      } else {
        final int top = _lastScrollPositions[newScript.uri] ?? 0;
        codeMirror.scrollTo(0, top);
      }
    }

    _refreshMarkers();
  }
}

class BreakpointsView {
  BreakpointsView(this._debuggerState, this._breakpointsCountDiv) {
    _items = new SelectableList<Breakpoint>()
      ..flex()
      ..clazz('menu-item-bottom-border')
      ..element.style.overflowY = 'scroll';

    _items.setRenderer((Breakpoint breakpoint) {
      final dynamic location = breakpoint.location;

      final CoreElement element = li(text: '', c: 'list-item');

      if (location is UnresolvedSourceLocation) {
        element.text = _debuggerState.getShortScriptName(location.script.uri);
        element.add(span(text: ' line ${location.line}', c: 'subtle'));
      } else if (location is SourceLocation) {
        element.text = _debuggerState.getShortScriptName(location.script.uri);

        // Modify the rendering slightly asynchronously.
        _debuggerState.getScript(location.script).then((Script script) {
          final Pos pos =
              _debuggerState.calculatePosition(script, location.tokenPos);
          element.add(span(text: ' line ${pos.line}', c: 'subtle'));
        });
      }

      if (!breakpoint.resolved) {
        element.add(span(text: ' (unresolved)', c: 'subtle'));
      }

      return element;
    });
  }

  Stream<Breakpoint> get onDoubleClick => _items.onDoubleClick;

  final DebuggerState _debuggerState;
  final CoreElement _breakpointsCountDiv;

  SelectableList<Breakpoint> _items;

  CoreElement get element => _items;

  Stream<Breakpoint> get onSelectionChanged => _items.onSelectionChanged;

  void showBreakpoints(List<Breakpoint> breakpoints) {
    breakpoints = breakpoints.toList();
    breakpoints.sort(_breakpointComparator);

    _items.setItems(breakpoints);
    _breakpointsCountDiv.text = breakpoints.length.toString();
  }
}

class CallStackView {
  CallStackView() {
    _items = new SelectableList<Frame>()
      ..flex()
      ..clazz('menu-item-bottom-border')
      ..element.style.overflowY = 'scroll';

    _items.setRenderer((Frame frame) {
      String name = frame.code?.name ?? '<none>';
      if (name.startsWith('[Unoptimized] ')) {
        name = name.substring('[Unoptimized] '.length);
      }

      String location = frame.location.script.uri;
      if (location.contains('/')) {
        location = location.substring(location.lastIndexOf('/') + 1);
      }

      final CoreElement element = li(
        text: name,
        c: 'list-item',
      )..add(span(text: ' $location', c: 'subtle'));
      return element;
    });
  }

  SelectableList<Frame> _items;

  CoreElement get element => _items;

  Stream<Frame> get onSelectionChanged => _items.onSelectionChanged;

  void showFrames(Stack stack, {bool selectTop = false}) {
    final List<Frame> frames = stack.frames;
    _items.setItems(frames, selection: frames.isEmpty ? null : frames.first);
  }

  void clearFrames() {
    _items.setItems(<Frame>[]);
  }
}

class VariablesView {
  VariablesView() {
    _items = new SelectableList<BoundVariable>()
      ..flex()
      ..clazz('menu-item-bottom-border')
      ..element.style.overflowY = 'scroll';

    _items.setRenderer((BoundVariable variable) {
      final String name = variable.name;
      final dynamic value = variable.value;
      String valueStr;
      if (value is InstanceRef) {
        if (value.valueAsString == null) {
          // TODO: also show an expandable toggle
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
      } else {
        valueStr = value.toString();
      }

      final CoreElement element = li(
        text: name,
        c: 'list-item',
      )..add(span(text: ' $valueStr', c: 'subtle'));
      return element;
    });
  }

  SelectableList<BoundVariable> _items;

  CoreElement get element => _items;

  void showVariables(Frame frame) {
    final List<BoundVariable> vars = frame.vars;
    _items.setItems(vars);
  }

  void clearVariables() {
    _items.setItems(<BoundVariable>[]);
  }
}

class ScriptAndPos {
  ScriptAndPos(this.uri, this.position);

  final String uri;
  final Pos position;

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
