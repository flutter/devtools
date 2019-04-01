// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// An application model used to programmatically query and drive the UI.
///
/// This is largely intended to aid in testing.

library model;

import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;

import 'package:vm_service_lib/vm_service_lib.dart';

import '../debugger/debugger.dart';
import '../framework/framework.dart';
import '../globals.dart';
import '../logging/logging.dart';
import '../main.dart';

class App {
  App(this.framework) {
    _register<void>('echo', echo);
    _register<void>('switchPage', switchPage);
    _register<String>('currentPageId', currentPageId);

    // ConnectDialog
    _register<void>('connectDialog.isVisible', connectDialogIsVisible);
    _register<void>('connectDialog.connectTo', connectDialogConnectTo);

    // LoggingScreen
    _register<void>('logging.clearLogs', logsClearLogs);
    _register<int>('logging.logCount', logsLogCount);

    // DebuggerScreen
    _register<String>('debugger.getState', debuggerGetState);
    _register<String>('debugger.getLocation', debuggerGetLocation);
    _register<void>('debugger.resume', debuggerResume);
    _register<void>('debugger.pause', debuggerPause);
    _register<void>('debugger.step', debuggerStep);
    _register<void>('debugger.clearBreakpoints', debuggerClearBreakpoints);
    _register<void>('debugger.addBreakpoint', debuggerAddBreakpoint);
    _register<void>(
        'debugger.setExceptionPauseMode', debuggerSetExceptionPauseMode);
    _register<List<String>>('debugger.getBreakpoints', debuggerGetBreakpoints);
    _register<bool>('debugger.supportsScripts', debuggerSupportsScripts);
    _register<List<String>>('debugger.getScripts', debuggerGetScripts);
    _register<List<String>>(
        'debugger.getCallStackFrames', debuggerGetCallStackFrames);
    _register<List<String>>('debugger.getVariables', debuggerGetVariables);
    _register<String>(
        'debugger.getConsoleContents', debuggerGetConsoleContents);
  }

  static void register(PerfToolFramework framework) {
    final App app = App(framework);
    app._bind();
  }

  final PerfToolFramework framework;

  void _bind() {
    final js.JsObject binding = js.JsObject.jsify(<dynamic, dynamic>{});
    binding['send'] = (String method, int id, dynamic arg) {
      try {
        final dynamic result = _dispatch(method, id, arg);
        Future<dynamic>.value(result).then((dynamic result) {
          _sendResponseResult(id, result);
        }).catchError((dynamic error, StackTrace stackTrace) {
          _sendReponseError(id, error, stackTrace);
        });
      } catch (error, stackTrace) {
        _sendReponseError(id, error, stackTrace);
      }
    };

    js.context['devtools'] = binding;
  }

  Future<void> echo(dynamic message) async {
    _sendNotification('app.echo', message);
  }

  Future<void> switchPage(dynamic pageId) async {
    final Screen screen = framework.getScreen(pageId);
    if (screen == null) {
      throw 'page $pageId not found';
    }
    framework.load(screen);
  }

  Future<String> currentPageId([dynamic _]) async {
    return framework.current?.id;
  }

  Future<bool> connectDialogIsVisible([dynamic _]) async {
    return framework.connectDialog.isVisible();
  }

  Future<void> connectDialogConnectTo([dynamic uri]) async {
    // uri comes as a String (from JSON) so needs changing back to a URI.
    return framework.connectDialog.connectTo(Uri.parse(uri));
  }

  Future<void> logsClearLogs([dynamic _]) async {
    final LoggingScreen screen = framework.getScreen('logging');
    screen.loggingTable.setRows(<LogData>[]);
  }

  Future<int> logsLogCount([dynamic _]) async {
    final LoggingScreen screen = framework.getScreen('logging');
    return screen.loggingTable.rowCount;
  }

  Future<String> debuggerGetState([dynamic _]) async {
    final DebuggerScreen screen = framework.getScreen('debugger');
    return screen.debuggerState.isPaused ? 'paused' : 'running';
  }

  Future<String> debuggerGetConsoleContents([dynamic _]) async {
    final DebuggerScreen screen = framework.getScreen('debugger');
    return screen.consoleArea.getContents();
  }

  Future<String> debuggerGetLocation([dynamic _]) async {
    final DebuggerScreen screen = framework.getScreen('debugger');
    final scriptAndPos = screen.sourceEditor.executionPoint;

    if (scriptAndPos == null) {
      return null;
    }

    return '${scriptAndPos.uri}:${scriptAndPos.position.line - 1}';
  }

  Future<void> debuggerResume([dynamic _]) async {
    final DebuggerScreen screen = framework.getScreen('debugger');
    await screen.debuggerState.resume();
  }

  Future<void> debuggerPause([dynamic _]) async {
    final DebuggerScreen screen = framework.getScreen('debugger');
    await screen.debuggerState.pause();
  }

  Future<void> debuggerStep([dynamic _]) async {
    final DebuggerScreen screen = framework.getScreen('debugger');
    await screen.debuggerState.stepOver();
  }

  Future<void> debuggerClearBreakpoints([dynamic _]) async {
    final DebuggerScreen screen = framework.getScreen('debugger');
    await screen.debuggerState.clearBreakpoints();
  }

  Future<List<String>> debuggerGetBreakpoints([dynamic _]) async {
    final DebuggerScreen screen = framework.getScreen('debugger');
    return screen.debuggerState.breakpoints.map((Breakpoint breakpoint) {
      return breakpoint.id;
    }).toList();
  }

  Future<bool> debuggerSupportsScripts([dynamic _]) async {
    return (await serviceManager.serviceCapabilities).supportsGetScripts;
  }

  Future<List<String>> debuggerGetScripts([dynamic _]) async {
    final DebuggerScreen screen = framework.getScreen('debugger');
    return screen.scriptsView.items.map((ScriptRef script) {
      return script.uri;
    }).toList();
  }

  Future<List<String>> debuggerGetCallStackFrames([dynamic _]) async {
    final DebuggerScreen screen = framework.getScreen('debugger');
    return screen.callStackView.items.map((Frame frame) {
      String name = frame.code?.name ?? '<none>';
      if (name.startsWith('[Unoptimized] ')) {
        name = name.substring('[Unoptimized] '.length);
      }

      String desc = '';

      if (frame.kind == FrameKind.kAsyncSuspensionMarker) {
        name = '<async break>';
      } else {
        desc = '${frame.location.script.uri}';

        if (desc.contains('/')) {
          desc = desc.substring(desc.lastIndexOf('/') + 1);
        }

        desc = ':$desc';
      }

      return '$name$desc';
    }).toList();
  }

  Future<List<String>> debuggerGetVariables([dynamic _]) async {
    final DebuggerScreen screen = framework.getScreen('debugger');
    return screen.variablesView.items.map((BoundVariable variable) {
      final dynamic value = variable.value;
      String valueStr;
      if (value is InstanceRef) {
        if (value.valueAsString == null) {
          valueStr = value.classRef.name;
        } else {
          valueStr = value.valueAsString;
        }
      } else if (value is Sentinel) {
        valueStr = value.valueAsString;
      } else {
        valueStr = value.toString();
      }
      return '${variable.name}:$valueStr';
    }).toList();
  }

  Future<void> debuggerAddBreakpoint([dynamic params]) async {
    final String path = params[0];
    final int line = params[1] + 1;

    final DebuggerScreen screen = framework.getScreen('debugger');
    await screen.debuggerState.addBreakpointByPathFragment(path, line);
  }

  Future<void> debuggerSetExceptionPauseMode([dynamic params]) async {
    final String mode = params;

    final DebuggerScreen screen = framework.getScreen('debugger');
    await screen.debuggerState.setExceptionPauseMode(mode);
  }

  void _sendNotification(String event, [dynamic params]) {
    final Map<String, dynamic> map = <String, dynamic>{
      'event': event,
    };
    if (params != null) {
      map['params'] = params;
    }
    print('[${jsonEncode(map)}]');
  }

  void _sendResponseResult(int id, [dynamic result]) {
    final Map<String, dynamic> map = <String, dynamic>{
      'id': id,
    };
    if (result != null) {
      map['result'] = result;
    }
    print('[${jsonEncode(map)}]');
  }

  void _sendReponseError(int id, dynamic error, StackTrace stackTrace) {
    final Map<String, dynamic> map = <String, dynamic>{
      'id': id,
      'error': <String, String>{
        'message': error.toString(),
        'stackTrace': stackTrace.toString(),
      },
    };
    print('[${jsonEncode(map)}]');
  }

  dynamic _dispatch(String method, int id, dynamic arg) {
    final Handler<dynamic> handler = _handlers[method];
    if (handler != null) {
      return handler(arg);
    } else {
      print('handler not found for $method()');
      throw 'no handler found for $method()';
    }
  }

  final Map<String, Handler<dynamic>> _handlers = <String, Handler<dynamic>>{};

  void _register<T>(String idMethod, Handler<T> fn) {
    _handlers[idMethod] = fn;
  }
}

typedef Handler<T> = Future<T> Function(dynamic arg);
