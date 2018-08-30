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

import 'package:devtools/main.dart';

import '../framework/framework.dart';
import '../logging/logging.dart';

// TODO(devoncarew): Only enable logging after enabled by the client.

class App {
  App(this.framework) {
    _register<void>('echo', echo);
    _register<void>('switchPage', switchPage);
    _register<String>('currentPageId', currentPageId);

    // LoggingScreen
    _register<void>('logs.clearLogs', logsClearLogs);
    _register<int>('logs.logCount', logsLogCount);
  }

  static void register(PerfToolFramework framework) {
    final App app = new App(framework);
    app._bind();
  }

  final PerfToolFramework framework;

  void _bind() {
    final js.JsObject binding = new js.JsObject.jsify(<dynamic, dynamic>{});
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

    _sendNotification('app.inited');
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

    // TODO(devoncarew): Listen for and log framework page change events?
  }

  Future<String> currentPageId([dynamic _]) async {
    return framework.current?.id;
  }

  Future<void> logsClearLogs([dynamic _]) async {
    final LoggingScreen screen = framework.getScreen('logs');
    screen.loggingTable.setRows(<LogData>[]);
  }

  Future<int> logsLogCount([dynamic _]) async {
    final LoggingScreen screen = framework.getScreen('logs');
    return screen.loggingTable.rows.length;
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

typedef Future<T> Handler<T>(dynamic arg);
