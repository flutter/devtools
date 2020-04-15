// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// An application model used to programmatically query and drive the UI.
///
/// This is largely intended to aid in testing.

library model;

import 'dart:async';
import 'dart:convert';

// TODO(jacobr): remove these dependencies on html_shim.
import 'dart:html' show window;
import 'dart:js' as js;
import 'dart:js_util' as js_util;

import 'package:vm_service/vm_service.dart';

import '../config_specific/logger/logger.dart';
import '../debugger/html_debugger_screen.dart';
import '../framework/html_framework.dart';
import '../globals.dart';
import '../logging/html_logging_screen.dart';
import '../logging/logging_controller.dart';
import '../main.dart';

class HtmlApp {
  HtmlApp(this.framework) {
    _register<void>('devToolsReady', devToolsReady);
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

  static HtmlApp register(HtmlPerfToolFramework framework) {
    return HtmlApp(framework).._bind();
  }

  final HtmlPerfToolFramework framework;

  void _bind() {
    final binding = js_util.newObject();
    js_util.setProperty(binding, 'send',
        js.allowInterop((String method, int id, dynamic arg) {
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
    }));

    js_util.setProperty(window, 'devtools', binding);
  }

  Future<void> devToolsReady(dynamic message) async {
    _sendNotification('app.devToolsReady', message);
  }

  Future<void> echo(dynamic message) async {
    _sendNotification('app.echo', message);
  }

  Future<void> switchPage(dynamic pageId) async {
    final HtmlScreen screen = framework.getScreen(pageId);
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
    final HtmlLoggingScreen screen = framework.getScreen('logging');
    screen.controller.loggingTableModel.setRows(<LogData>[]);
  }

  Future<int> logsLogCount([dynamic _]) async {
    final HtmlLoggingScreen screen = framework.getScreen('logging');
    return screen.controller.loggingTableModel.rowCount;
  }

  Future<String> debuggerGetState([dynamic _]) async {
    final HtmlDebuggerScreen screen = framework.getScreen('debugger');
    return screen.debuggerState.isPaused.value ? 'paused' : 'running';
  }

  Future<String> debuggerGetConsoleContents([dynamic _]) async {
    final HtmlDebuggerScreen screen = framework.getScreen('debugger');
    return screen.consoleArea.styledContents();
  }

  Future<String> debuggerGetLocation([dynamic _]) async {
    final HtmlDebuggerScreen screen = framework.getScreen('debugger');
    final scriptAndPos = screen.sourceEditor.executionPoint;

    if (scriptAndPos == null) {
      return null;
    }

    return '${scriptAndPos.uri}:${scriptAndPos.position.line - 1}';
  }

  Future<void> debuggerResume([dynamic _]) async {
    final HtmlDebuggerScreen screen = framework.getScreen('debugger');
    await screen.debuggerState.resume();
  }

  Future<void> debuggerPause([dynamic _]) async {
    final HtmlDebuggerScreen screen = framework.getScreen('debugger');
    await screen.debuggerState.pause();
  }

  Future<void> debuggerStep([dynamic _]) async {
    final HtmlDebuggerScreen screen = framework.getScreen('debugger');
    await screen.debuggerState.stepOver();
  }

  Future<void> debuggerClearBreakpoints([dynamic _]) async {
    final HtmlDebuggerScreen screen = framework.getScreen('debugger');
    await screen.debuggerState.clearBreakpoints();
  }

  Future<List<String>> debuggerGetBreakpoints([dynamic _]) async {
    final HtmlDebuggerScreen screen = framework.getScreen('debugger');
    return screen.debuggerState.breakpoints.value
        .map((breakpoint) => breakpoint.id)
        .toList();
  }

  Future<bool> debuggerSupportsScripts([dynamic _]) async {
    return (await serviceManager.serviceCapabilities).supportsGetScripts;
  }

  Future<List<String>> debuggerGetScripts([dynamic _]) async {
    final HtmlDebuggerScreen screen = framework.getScreen('debugger');
    return screen.scriptsView.items.map((ScriptRef script) {
      return script.uri;
    }).toList();
  }

  Future<List<String>> debuggerGetCallStackFrames([dynamic _]) async {
    final HtmlDebuggerScreen screen = framework.getScreen('debugger');
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
    final HtmlDebuggerScreen screen = framework.getScreen('debugger');
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

    final HtmlDebuggerScreen screen = framework.getScreen('debugger');
    await screen.debuggerState.addBreakpointByPathFragment(path, line);
  }

  Future<void> debuggerSetExceptionPauseMode([dynamic params]) async {
    final String mode = params;

    final HtmlDebuggerScreen screen = framework.getScreen('debugger');
    await screen.debuggerState.setExceptionPauseMode(mode);
  }

  void _sendNotification(String event, [dynamic params]) {
    final Map<String, dynamic> map = <String, dynamic>{
      'event': event,
    };
    if (params != null) {
      map['params'] = params;
    }
    // TODO(terry): Shouldn't print to console by default.
    log('[${jsonEncode(map)}]');
  }

  void _sendResponseResult(int id, [dynamic result]) {
    final Map<String, dynamic> map = <String, dynamic>{
      'id': id,
    };
    if (result != null) {
      map['result'] = result;
    }
    // TODO(terry): Shouldn't print to console by default.
    log('[${jsonEncode(map)}]');
  }

  void _sendReponseError(int id, dynamic error, StackTrace stackTrace) {
    final Map<String, dynamic> map = <String, dynamic>{
      'id': id,
      'error': <String, String>{
        'message': error.toString(),
        'stackTrace': stackTrace.toString(),
      },
    };
    // TODO(terry): Better error message to user and log to GA too?
    log('[${jsonEncode(map)}]', LogLevel.error);
  }

  dynamic _dispatch(String method, int id, dynamic arg) {
    final Handler<dynamic> handler = _handlers[method];
    if (handler != null) {
      return handler(arg);
    } else {
      log('handler not found for $method()', LogLevel.error);
      throw 'no handler found for $method()';
    }
  }

  final Map<String, Handler<dynamic>> _handlers = <String, Handler<dynamic>>{};

  void _register<T>(String idMethod, Handler<T> fn) {
    _handlers[idMethod] = fn;
  }
}

typedef Handler<T> = Future<T> Function(dynamic arg);
