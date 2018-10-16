// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:codemirror/codemirror.dart';
import 'package:rxdart/rxdart.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import '../framework/framework.dart';
import '../globals.dart';
import '../ui/custom.dart';
import '../ui/elements.dart';
import '../ui/primer.dart';

// TODO: console output area

// TODO: add an API around the editor area

// TODO: add a breakpoints manager and area

// TODO: improve the look of the current execution line

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

  SelectableList<LibraryRef> _scriptItems;
  CoreElement _scriptCountDiv;
  CoreElement _sourcePathDiv;

  SourceEditor sourceEditor;
  DebuggerState debuggerState;

  @override
  void createContent(Framework framework, CoreElement mainDiv) {
    CoreElement sourceArea;

    debuggerState = new DebuggerState();

    final PButton pauseButton = new PButton(null)
      ..primary()
      ..small()
      ..element.style.minWidth = '90px';

    pauseButton.click(() async {
      pauseButton.disabled = true;

      if (debuggerState.isPaused) {
        await debuggerState.resume();
      } else {
        await debuggerState.pause();
      }

      pauseButton.disabled = false;
    });

    debuggerState.onPausedChanged.listen((bool isPaused) {
      pauseButton.clear();

      final String icon =
          isPaused ? 'octicon-triangle-right' : 'octicon-primitive-dot';
      pauseButton.add(<CoreElement>[
        span(c: 'octicon $icon'),
        span(text: isPaused ? 'Resume' : 'Pause'),
      ]);
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
                  pauseButton,
                  div(c: 'btn-group margin-left')
                    ..add(<CoreElement>[
                      stepOver = new PButton(null)
                        ..add(<CoreElement>[
                          span(c: 'octicon octicon-chevron-right'),
                          span(text: 'Step over'),
                        ])
                        ..small(),
                      stepIn = new PButton(null)
                        ..add(<CoreElement>[
                          span(c: 'octicon octicon-chevron-down'),
                          span(text: 'Step in'),
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
                  new PButton('Foo bar')..small(),
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
    codeMirrorElement.style.height = '100%';

    sourceEditor = new SourceEditor(codeMirror, debuggerState);

    debuggerState.onBreakpointsChanged
        .listen((List<Breakpoint> breakpoints) async {
      sourceEditor.setBreakpoints(breakpoints);
    });

    debuggerState.onPausedChanged.listen((bool paused) async {
      if (!paused) {
        sourceEditor.clearExecutionPoint();
        return;
      }

      // todo: use async frames
      final Stack stack = await debuggerState.getStack();

      if (stack.frames.isNotEmpty) {
        final Frame frame = stack.frames.first;
        final SourceLocation location = frame.location;
        final ScriptRef scriptRef = location.script;
        final Script script = await debuggerState.getScript(scriptRef);
        final Pos position =
            debuggerState.calculatePosition(script, location.tokenPos);
        sourceEditor.setExecutionPoint(position);
      }
    });
  }

  CoreElement _buildMenuNav() {
    // TODO: expand / collapse

    final PNavMenu menu = new PNavMenu(<PNavMenuItem>[
      new PNavMenuItem('Call stack'),
      new PNavMenuItem('Variables'),
      new PNavMenuItem('Breakpoints'),
      new PNavMenuItem('Scripts')
        ..add(
          _scriptCountDiv = span(text: '0', c: 'counter'),
        ),
    ], supportsSelection: false)
      ..flex()
      ..layoutVertical();

    // TODO: handle selection changes

    _scriptItems = menu.add(new SelectableList<LibraryRef>()
      ..flex()
      ..element.style.overflowY = 'scroll');

    _scriptItems.onSelectionChanged.listen((LibraryRef libraryRef) async {
      final IsolateRef isolateRef = serviceInfo.isolateManager.selectedIsolate;
      dynamic result =
          await serviceInfo.service.getObject(isolateRef.id, libraryRef.id);

      if (result is Library) {
        final Library library = result;
        if (library.scripts.isNotEmpty) {
          final ScriptRef scriptRef =
              library.scripts.firstWhere((ScriptRef ref) {
            return library.uri == ref.uri;
          }, orElse: () => library.scripts.first);
          result =
              await serviceInfo.service.getObject(isolateRef.id, scriptRef.id);

          if (result is Script) {
            _displaySource(result);
          }
        } else {
          _displaySource(null);
        }
      }
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

  void _populateFromIsolate(Isolate isolate) {
    // TODO: populate the scripts by querying each library

    final List<LibraryRef> libraryRefs = isolate.libraries.toList();

    String prefix = isolate.rootLib.uri;
    if (prefix.contains('/lib/')) {
      prefix = prefix.substring(0, prefix.lastIndexOf('/lib/'));
      if (prefix.contains('/')) {
        prefix = prefix.substring(0, prefix.lastIndexOf('/'));
      }
    } else if (prefix.contains('/bin/')) {
      prefix = prefix.substring(0, prefix.lastIndexOf('/bin/'));
      if (prefix.contains('/')) {
        prefix = prefix.substring(0, prefix.lastIndexOf('/'));
      }
    } else {
      prefix = null;
    }

    libraryRefs.sort((LibraryRef ref1, LibraryRef ref2) {
      final String uri1 = ref1.uri;
      final String uri2 = ref2.uri;

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

    _scriptItems.setRenderer((LibraryRef libraryRef) {
      final String uri = libraryRef.uri;
      String name = uri;
      if (prefix != null && name.startsWith(prefix)) {
        name = uri.substring(prefix.length);
      }
      final CoreElement element = li(text: name, c: 'list-item');
      if (name != uri) {
        element.add(span(text: ' $uri', c: 'subtle'));
      }
      element.tooltip = uri;
      return element;
    });

    _scriptItems.setItems(libraryRefs);

    _scriptCountDiv.text = libraryRefs.length.toString();
  }

  void _displaySource(Script script) {
    debuggerState.lastScriptId = script?.id;

    if (script == null) {
      _sourcePathDiv.setInnerHtml('&nbsp;');
      sourceEditor.displayScript(script);
      return;
    }

    _sourcePathDiv.text = script.uri;

    sourceEditor.displayScript(script);
  }
}

class DebuggerState {
  DebuggerState();

  // handle EventKind.kIsolateReload

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
      // TODO:
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

      // TODO: sort
      _breakpoints.add(isolate.breakpoints.toList());
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

  // TODO: temp
  String lastScriptId;

  Future<void> addBreakpoint(int line) {
    return service.addBreakpoint(isolateRef.id, lastScriptId, line);
  }

  Future<Stack> getStack() {
    return service.getStack(isolateRef.id);
  }

  void _handleIsolateEvent(Event event) {
    if (event.isolate.id != isolateRef.id) {
      return;
    }

    _stepping.add(event.topFrame != null);

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
        // TODO: sort
        _breakpoints.add(_breakpoints.value.toList());
        break;
      case EventKind.kBreakpointResolved:
        _breakpoints.value.remove(event.breakpoint);
        _breakpoints.value.add(event.breakpoint);
        // TODO: sort
        _breakpoints.add(_breakpoints.value.toList());
        break;
      case EventKind.kBreakpointRemoved:
        _breakpoints.value.remove(event.breakpoint);
        _breakpoints.add(_breakpoints.value.toList());
        break;
    }
  }

  void _clearCaches() {
    // TODO:
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
}

class Pos {
  Pos(this.line, this.column);

  final int line;
  final int column;

  @override
  String toString() => '$line $column';
}

class SourceEditor {
  SourceEditor(this.codeMirror, this.debuggerState) {
    // TODO:

    codeMirror.onEvent('gutterClick', true).listen((dynamic line) {
      if (line is int) {
        final dynamic info = codeMirror.callArg('getLineHandle', line);
        final bool addingBreakpoint = info['gutterMarkers'] == null;

        // TODO: add or remove a breakpoint
        codeMirror.setGutterMarker(
          line,
          'breakpoints',
          addingBreakpoint
              ? span(c: 'octicon octicon-primitive-dot').element
              : null,
        );

        //sourceEditor.addLineClass(line, '', '');

        if (addingBreakpoint) {
          debuggerState.addBreakpoint(line + 1);
        }
      }
    });
  }

  final CodeMirror codeMirror;

  // TODO: move debuggerState out of this class
  final DebuggerState debuggerState;

  Script script;
  int executionLine;
  List<Breakpoint> breakpoints = <Breakpoint>[];

  void setBreakpoints(List<Breakpoint> breakpoints) {
    this.breakpoints = breakpoints;

    _refreshMarkers();
  }

  void _refreshMarkers() {
    codeMirror.clearGutter('breakpoints');

    if (script == null) {
      return;
    }

    for (Breakpoint breakpoint in breakpoints) {
      if (breakpoint.location is SourceLocation) {
        final SourceLocation loc = breakpoint.location;

        if (loc.script.id != script.id) {
          continue;
        }

        final Pos pos = debuggerState.calculatePosition(script, loc.tokenPos);

        codeMirror.setGutterMarker(
          pos.line - 1,
          'breakpoints',
          span(c: 'octicon octicon-primitive-dot').element,
        );
      } else if (breakpoint.location is UnresolvedSourceLocation) {
        final UnresolvedSourceLocation loc = breakpoint.location;

        if (loc.script.id != script.id) {
          continue;
        }

        codeMirror.setGutterMarker(
          loc.line - 1,
          'breakpoints',
          span(c: 'octicon octicon-primitive-dot').element,
        );
      }
    }

    if (executionLine != null) {
      codeMirror.setGutterMarker(
        executionLine,
        'breakpoints',
        span(c: 'octicon octicon-arrow-right').element,
      );
    }
  }

  void clearExecutionPoint() {
    if (executionLine == null) {
      return;
    }

    executionLine = null;
    _refreshMarkers();
  }

  void setExecutionPoint(Pos position) {
    // todo: show column position
    executionLine = position.line - 1;
    _refreshMarkers();
  }

  void displayScript(Script script) {
    this.script = script;

    if (script == null) {
      codeMirror.getDoc().setValue('');
    } else {
      final String source = script?.source ?? '<source not available>';
      codeMirror.getDoc().setValue(source);
      codeMirror.scrollTo(0, 0);
    }

    _refreshMarkers();
  }
}
