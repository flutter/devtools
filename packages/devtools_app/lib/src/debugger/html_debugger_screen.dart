// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:codemirror/codemirror.dart';
import 'package:html_shim/html.dart' as html;
import 'package:meta/meta.dart';
import 'package:split/split.dart' as split;
import 'package:vm_service/vm_service.dart';

import '../core/message_bus.dart';
import '../debugger/breakpoints_view.dart';
import '../debugger/callstack_view.dart';
import '../debugger/console_area.dart';
import '../debugger/debugger_state.dart';
import '../debugger/html_scripts_view.dart';
import '../debugger/html_variables_view.dart';
import '../framework/html_framework.dart';
import '../globals.dart';
import '../ui/analytics.dart' as ga;
import '../ui/analytics_platform.dart' as ga_platform;
import '../ui/html_elements.dart';
import '../ui/icons.dart';
import '../ui/primer.dart';
import '../ui/theme.dart';
import '../ui/ui_utils.dart';

// TODO(devoncarew): improve selection behavior in the left nav area

// TODO(devoncarew): have the console area be collapsible

// TODO(devoncarew): handle cases of isolates terminating and new isolates
// replacing them (flutter hot restart)

// TODO(devoncarew): show toasts for some events (new isolate creation)

// TODO(devoncarew): handle displaying large lists, maps, in the variables view

class HtmlDebuggerScreen extends HtmlScreen {
  HtmlDebuggerScreen({
    bool enabled,
    String disabledTooltip,
  })  : debuggerState = DebuggerState(),
        super(
          name: 'Debugger',
          id: 'debugger',
          iconClass: 'octicon-bug',
          enabled: enabled,
          disabledTooltip: disabledTooltip,
        ) {
    shortcutCallback = debuggerShortcuts;
    deviceStatus = HtmlStatusItem();
    addStatusItem(deviceStatus);
  }

  final DebuggerState debuggerState;

  bool _initialized = false;

  HtmlStatusItem deviceStatus;

  CoreElement _breakpointsCountDiv;

  CoreElement _sourcePathDiv;

  CoreElement _popupTextfield;

  HtmlPopupView _popupView;

  SourceEditor sourceEditor;

  CallStackView callStackView;

  HtmlVariablesView variablesView;

  BreakpointsView breakpointsView;

  HtmlScriptsView scriptsView;

  HtmlScriptsView popupScriptsView;

  ConsoleArea consoleArea;

  HtmlScriptsMatcher _matcher;

  List<CoreElement> _navEditorPanels;

  CoreElement _sourceArea;

  CoreElement _consoleDiv;

  // Handle shortcut keys
  //
  // All shortcut keys start with CTRL key plus another alphanumeric key.
  //
  // Shortcut keys supported:
  //
  //   O - open (letter O) a script file, sets focus to the script_name field
  //       in the Scripts views list.
  //
  bool debuggerShortcuts(bool ctrlKey, bool shiftKey, bool altKey, String key) {
    if (ctrlKey) {
      switch (key) {
        case 'o': // CTRL + o
          if (_matcher != null && _matcher.active) {
            _matcher.cancel();
            _matcher = null;
          }
          _popupView.element.style.display = 'inline';

          if (!_popupView.isPoppedUp) {
            _popupView.showPopup();
            _hookupListeners(_popupView.scriptsView);
          } else {
            _popupView.scriptsView.clearScripts();
            _popupView.scriptsView.element.element.style.display = 'inline';
          }

          // Open a file set focus to the 'popup_script_name' textfield
          // accepts key strokes.
          _popupView.popupTextfield.element.focus();

          ga.select(ga.debugger, ga.openShortcut);

          return true;
          break;
      }
    }

    return false;
  }

  @override
  CoreElement createContent(HtmlFramework framework) {
    ga_platform.setupDimensions();

    final CoreElement screenDiv = div(c: 'custom-scrollbar')..layoutVertical();

    final PButton resumeButton =
        PButton.icon('Resume', FlutterIcons.resume_white_disabled_2x)
          ..primary()
          ..small()
          ..clazz('margin-left')
          ..disabled = true;

    final PButton pauseButton =
        PButton.icon('Pause', FlutterIcons.pause_black_2x)..small();

    void _updateResumeButton({@required bool disabled}) {
      resumeButton.disabled = disabled;
    }

    void _updatePauseButton({@required bool disabled}) {
      pauseButton.disabled = disabled;
    }

    resumeButton.click(() async {
      ga.select(ga.debugger, ga.resume);
      _updateResumeButton(disabled: true);
      await debuggerState.resume();
      _updateResumeButton(disabled: false);
    });

    pauseButton.click(() async {
      ga.select(ga.debugger, ga.pause);
      _updatePauseButton(disabled: true);
      await debuggerState.pause();
      _updatePauseButton(disabled: false);
    });

    // TODO(#926): Is this necessary?
    _updatePauseButton(disabled: debuggerState.isPaused.value);
    _updateResumeButton(disabled: !debuggerState.isPaused.value);
    debuggerState.isPaused.addListener(() {
      _updatePauseButton(disabled: debuggerState.isPaused.value);
      _updateResumeButton(disabled: !debuggerState.isPaused.value);
    });

    PButton stepOver, stepIn, stepOut;

    final BreakOnExceptionControl breakOnExceptionControl =
        BreakOnExceptionControl();
    breakOnExceptionControl.onPauseModeChanged.listen((String mode) {
      debuggerState.setExceptionPauseMode(mode);
    });
    // TODO(#926): Is this necessary?
    breakOnExceptionControl.exceptionPauseMode =
        debuggerState.exceptionPauseMode.value;
    debuggerState.exceptionPauseMode.addListener(() {
      breakOnExceptionControl.exceptionPauseMode =
          debuggerState.exceptionPauseMode.value;
    });

    consoleArea = ConsoleArea();

    _popupTextfield =
        CoreElement('input', classes: 'form-control input-sm popup-textfield')
          ..setAttribute('type', 'text')
          ..setAttribute('placeholder', 'search')
          ..id = 'popup_script_name'
          ..focus(() {
            _matcher ??= HtmlScriptsMatcher(debuggerState);
            popupScriptsView.setMatcher(_matcher);
          })
          ..blur(() {
            Timer(const Duration(milliseconds: 200),
                () => _matcher?.finish()); // Hide/clear the popup.
          })
          ..onKeyUp.listen((html.KeyboardEvent e) {
            switch (e.keyCode) {
              case DOM_VK_RETURN:
              case DOM_VK_ESCAPE:
              case DOM_VK_PAGE_UP:
              case DOM_VK_PAGE_DOWN:
              case DOM_VK_END:
              case DOM_VK_HOME:
              case DOM_VK_UP:
              case DOM_VK_DOWN:
                return;
              default:
                final html.InputElement inputElement = _popupTextfield.element;
                final String value = inputElement.value.trim();

                if (!_matcher.active) {
                  _matcher.start(
                    sourceEditor.scriptRef,
                    popupScriptsView,
                    _popupTextfield,
                    _popupView.hidePopup,
                  );
                }
                _matcher.displayMatchingScripts(value);
            }
          });

    screenDiv.add(<CoreElement>[
      div(c: 'section')
        ..flex()
        ..layoutHorizontal()
        ..add(_navEditorPanels = <CoreElement>[
          div(c: 'debugger-menu')
            ..layoutVertical()
            ..add(<CoreElement>[
              _buildMenuNav(),
            ]),
          div()
            ..element.style.overflowX = 'hidden'
            ..layoutVertical()
            ..add(<CoreElement>[
              div(c: 'section flex-wrap')
                ..layoutHorizontal()
                ..add(<CoreElement>[
                  div(c: 'btn-group collapsible-785 flex-no-wrap')
                    ..add(<CoreElement>[
                      pauseButton,
                      resumeButton,
                    ]),
                  div(c: 'btn-group flex-no-wrap margin-left collapsible-1000')
                    ..add(<CoreElement>[
                      stepIn = PButton.octicon('Step in', icon: 'chevron-down'),
                      stepOver =
                          PButton.octicon('Step over', icon: 'chevron-right'),
                      stepOut = PButton.octicon('Step out', icon: 'chevron-up'),
                    ]),
                  div(c: 'margin-right')..flex(),
                  breakOnExceptionControl,
                ]),
              _sourceArea = div(c: 'section table-border')
                ..layoutVertical()
                ..add(<CoreElement>[
                  _sourcePathDiv = div(c: 'source-head'),
                ]),
              _consoleDiv = div(c: 'section table-border')
                ..layoutVertical()
                ..add(consoleArea.element),
            ]),
        ]),
    ]);

    screenDiv.add([
      _popupTextfield,
      _popupView = HtmlPopupView(
        popupScriptsView,
        _sourceArea,
        _sourcePathDiv,
        _popupTextfield,
      )
    ]);

    _sourcePathDiv.setInnerHtml('&nbsp;');

    void updateStepCapabilities() {
      final value = debuggerState.supportsStepping.value;
      stepIn.enabled = value;

      // Only enable step over and step out if we're paused at a frame. When
      // paused w/o a frame (in the message loop), step over and out aren't
      // meaningful.
      stepOver.enabled = value && (debuggerState.lastEvent.topFrame != null);
      stepOut.enabled = value && (debuggerState.lastEvent.topFrame != null);
    }

    // TODO(#926): Is this necessary?
    updateStepCapabilities();
    debuggerState.supportsStepping.addListener(updateStepCapabilities);

    stepOver.click(() => debuggerState.stepOver());
    stepIn.click(() => debuggerState.stepIn());
    stepOut.click(() => debuggerState.stepOut());

    void updateFrames() async {
      if (debuggerState.isPaused.value) {
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
        sourceEditor?.clearExecutionPoint();
      }
    }

    // TODO(#926): Is this necessary?
    updateFrames();
    debuggerState.isPaused.addListener(updateFrames);

    void updateStatusLine() async {
      if (debuggerState.isPaused.value &&
          debuggerState.lastEvent.topFrame != null) {
        final Frame topFrame = debuggerState.lastEvent.topFrame;

        final ScriptRef scriptRef = topFrame.location.script;
        final Script script = await debuggerState.getScript(scriptRef);
        final SourcePosition position =
            debuggerState.calculatePosition(script, topFrame.location.tokenPos);

        final String file =
            scriptRef.uri.substring(scriptRef.uri.lastIndexOf('/') + 1);
        deviceStatus.element.text =
            'paused at $file ${position.line}:${position.column}';
      } else {
        deviceStatus.element.text = '';
      }
    }

    // TODO(#926): Is this necessary?
    updateStatusLine();
    debuggerState.isPaused.addListener(updateStatusLine);

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

    messageBus.onEvent(type: 'reload.start').listen((_) {
      consoleArea.clear();
    });
    messageBus.onEvent(type: 'reload.end').listen((BusEvent event) {
      consoleArea.appendText('${event.data}\n\n');
    });
    messageBus.onEvent(type: 'restart.start').listen((_) {
      consoleArea.clear();
    });
    messageBus.onEvent(type: 'restart.end').listen((BusEvent event) {
      consoleArea.appendText('${event.data}\n\n');
    });

    return screenDiv;
  }

  @override
  void onContentAttached() {
    // configure the navigation / editor splitter
    split.flexSplit(
      html.toDartHtmlElementList(
          _navEditorPanels.map((e) => e.element).toList()),
      gutterSize: defaultSplitterWidth,
      sizes: [22, 78],
      minSize: [200, 600],
    );

    // configure the editor / console splitter
    split.flexSplit(
      html.toDartHtmlElementList([_sourceArea.element, _consoleDiv.element]),
      horizontal: false,
      gutterSize: defaultSplitterWidth,
      sizes: [80, 20],
      minSize: [200, 60],
    );

    final options = <String, dynamic>{
      'mode': 'dart',
      'lineNumbers': true,
      'gutters': <String>['breakpoints'],
    };
    final codeMirror = CodeMirror.fromElement(
        html.toDartHtmlElement(_sourceArea.element),
        options: options);
    codeMirror.setReadOnly(true);
    if (isDarkTheme) {
      codeMirror.setTheme('darcula');
    }
    final codeMirrorElement = _sourcePathDiv.element.parent.children[1];
    codeMirrorElement.setAttribute('flex', '');

    sourceEditor = SourceEditor(codeMirror, debuggerState);

    // TODO(#926): Is this necessary?
    sourceEditor.setBreakpoints(debuggerState.breakpoints.value);
    debuggerState.breakpoints.addListener(() {
      sourceEditor.setBreakpoints(debuggerState.breakpoints.value);
    });
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

  void _hookupListeners(HtmlScriptsView scriptsView) {
    scriptsView.onSelectionChanged.listen((ScriptRef scriptRef) async {
      if (scriptsView.itemsHadClicked && _matcher != null && _matcher.active) {
        // User clicked while matcher was active then reset the matcher.
        _matcher.reset();
      }

      if (_matcher != null && _matcher.active) return;

      if (scriptRef == null) {
        _displaySource(null);
        return;
      }

      final IsolateRef isolateRef =
          serviceManager.isolateManager.selectedIsolate;
      final dynamic result =
          await serviceManager.service.getObject(isolateRef.id, scriptRef.id);

      if (result is Script) {
        _displaySource(result, scriptRef);
      } else {
        _displaySource(null);
      }
    });
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
      if (ref == null) {
        return null;
      }

      if (ref.valueAsString != null && !ref.valueAsStringIsTruncated) {
        return ref.valueAsString;
      } else {
        final dynamic result = await serviceManager.service.invoke(
          debuggerState.isolateRef.id,
          ref.id,
          'toString',
          <String>[],
          disableBreakpoints: true,
        );

        if (result is ErrorRef) {
          return '${result.kind} ${result.message}';
        } else if (result is InstanceRef) {
          final String str = await _retrieveFullStringValue(result);
          return str;
        } else {
          // TODO: Improve the return value for this case.
          return null;
        }
      }
    };
    variablesView = HtmlVariablesView(debuggerState, describer);

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

    final CoreElement textfield =
        CoreElement('input', classes: 'form-control input-sm margin-left')
          ..setAttribute('type', 'text')
          ..setAttribute('placeholder', 'search')
          ..element.style.width = 'calc(100% - 110px)'
          ..id = 'script_name';
    final CoreElement scriptCountDiv = span(text: '-', c: 'counter')
      ..element.style.marginTop = '4px';

    scriptsView = HtmlScriptsView(debuggerState.getShortScriptName);
    _hookupListeners(scriptsView);

    popupScriptsView = HtmlScriptsView(debuggerState.getShortScriptName);
    _hookupListeners(popupScriptsView);

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
      PNavMenuItem('Libraries')
        ..add([
          textfield
            ..click(() {
              _matcher ??= HtmlScriptsMatcher(debuggerState);
              scriptsView.setMatcher(_matcher);
            })
            ..focus(() {
              _matcher ??= HtmlScriptsMatcher(debuggerState);
              scriptsView.setMatcher(_matcher);
            })
            ..onKeyUp.listen((html.KeyboardEvent e) {
              switch (e.keyCode) {
                case DOM_VK_RETURN:
                case DOM_VK_ESCAPE:
                case DOM_VK_PAGE_UP:
                case DOM_VK_PAGE_DOWN:
                case DOM_VK_END:
                case DOM_VK_HOME:
                case DOM_VK_UP:
                case DOM_VK_DOWN:
                  return;
                default:
                  final html.InputElement inputElement = textfield.element;
                  final String value = inputElement.value.trim();
                  if (!_matcher.active) {
                    _matcher.start(
                      sourceEditor.scriptRef,
                      scriptsView,
                      textfield,
                    );
                  }
                  _matcher.displayMatchingScripts(value);
              }
            }),
          scriptCountDiv,
        ])
        ..click(() => scriptsView.element.toggleAttribute('hidden')),
      scriptsView.element,
    ], supportsSelection: false)
      ..flex()
      ..layoutVertical();

    // TODO(#926): Is this necessary?
    breakpointsView.showBreakpoints(debuggerState.breakpoints.value);
    debuggerState.breakpoints.addListener(() {
      breakpointsView.showBreakpoints(debuggerState.breakpoints.value);
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
        _populateFromIsolate(result, [scriptsView, popupScriptsView]);
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

  /// Populate the ScriptsViews - the library UI list and the file open pop-up.
  void _populateFromIsolate(
      Isolate isolate, List<HtmlScriptsView> scriptsViewers) async {
    debuggerState.setRootLib(isolate.rootLib);
    debuggerState.updateFrom(isolate);

    final bool isRunning = isolate.pauseEvent == null ||
        isolate.pauseEvent.kind == EventKind.kResume;

    final getScriptsSupport =
        (await serviceManager.serviceCapabilities).supportsGetScripts;
    if (getScriptsSupport) {
      final ScriptList scriptList =
          await serviceManager.service.getScripts(isolate.id);
      final List<ScriptRef> scripts = scriptList.scripts.toList();

      debuggerState.scripts = scripts;

      for (HtmlScriptsView scriptsViewer in scriptsViewers) {
        scriptsView.matcher?.cancel();
        scriptsViewer.showScripts(
          scripts,
          debuggerState.rootLib.uri,
          debuggerState.commonScriptPrefix,
          selectRootScript: isRunning,
        );
        scriptsViewer.matcher?.updateScripts();
      }
    }
  }

  /// scriptRef is the current displayed script file ScriptRef.
  void _displaySource(Script script, [ScriptRef scriptRef]) {
    if (script == null) {
      sourceEditor.displayScript(script);
    } else {
      _sourcePathDiv.text = script.uri;
      sourceEditor.displayScript(script);
      sourceEditor.scriptRef = scriptRef;
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
  ScriptRef scriptRef;
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
          html.toDartHtmlElement(
              span(c: 'octicon octicon-primitive-dot').element),
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
          html.toDartHtmlElement(
              span(c: 'octicon octicon-primitive-dot').element),
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
        html.toDartHtmlElement(_executionPointElement.element),
      );
    }
  }

  void clearExecutionPoint() {
    executionPoint = null;
    _clearLineClass();
    _refreshMarkers();
  }

  final Map<String, num> _lastScrollPositions = <String, num>{};

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
        final num top = _lastScrollPositions[newScript.uri] ?? 0;
        codeMirror.scrollTo(0, top);
      }
    }

    _executionPointElement?.dispose();
    _executionPointElement = null;

    _refreshMarkers();
  }
}

class ScriptAndPosition {
  ScriptAndPosition(this.script, {@required this.position});

  final Script script;
  final SourcePosition position;

  String get uri => script.uri;

  bool matches(Script script) => uri == script.uri;
}
