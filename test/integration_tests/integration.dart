// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart'
    show ConsoleAPIEvent, RemoteObject;

import '../support/chrome.dart';
import '../support/cli_test_driver.dart';

const bool verboseTesting = false;

WebdevFixture webdevFixture;
BrowserManager browserManager;

Future<void> waitFor(
  Future<bool> condition(), {
  Duration timeout = const Duration(seconds: 4),
  String timeoutMessage = 'condition not satisfied',
}) async {
  final DateTime end = DateTime.now().add(timeout);

  while (!end.isBefore(DateTime.now())) {
    if (await condition()) {
      return;
    }

    await shortDelay();
  }

  throw timeoutMessage;
}

Future delay() {
  return Future.delayed(const Duration(milliseconds: 500));
}

Future shortDelay() {
  return Future.delayed(const Duration(milliseconds: 100));
}

class DevtoolsManager {
  DevtoolsManager(this.tabInstance, this.baseUri);

  final BrowserTabInstance tabInstance;
  final Uri baseUri;

  Future<void> start(AppFixture appFixture) async {
    final Uri baseAppUri =
        baseUri.resolve('index.html?port=${appFixture.servicePort}');
    await tabInstance.tab.navigate(baseAppUri.toString());

    await delay();

    // wait for app initialization
    await tabInstance.getBrowserChannel();
  }

  Future<void> switchPage(String page) async {
    await tabInstance.send('switchPage', page);
  }

  Future<String> currentPageId() async {
    final AppResponse response = await tabInstance.send('currentPageId');
    return response.result;
  }
}

class BrowserManager {
  BrowserManager._(this.chromeProcess, this.tab);

  static Future<BrowserManager> create() async {
    final Chrome chrome = Chrome.locate();
    if (chrome == null) {
      throw 'unable to locate Chrome';
    }

    final ChromeProcess chromeProcess = await chrome.start();
    final ChromeTab tab = await chromeProcess.getFirstTab();

    await tab.connect();

    return BrowserManager._(chromeProcess, tab);
  }

  final ChromeProcess chromeProcess;
  final ChromeTab tab;

  Future<BrowserTabInstance> createNewTab() async {
    final String targetId = await this.tab.createNewTarget();

    await delay();

    final ChromeTab tab =
        await chromeProcess.connectToTabId('localhost', targetId);
    await tab.connect(verbose: true);

    await delay();

    await tab.wipConnection.target.activateTarget(targetId);

    await delay();

    return BrowserTabInstance(tab);
  }

  Future<void> teardown() async {
    chromeProcess.kill();
  }
}

class BrowserTabInstance {
  BrowserTabInstance(this.tab) {
    tab.onConsoleAPICalled
        .where((ConsoleAPIEvent event) => event.type == 'log')
        .listen((ConsoleAPIEvent event) {
      if (event.args.isNotEmpty) {
        final RemoteObject message = event.args.first;
        final String value = '${message.value}';
        if (value.startsWith('[') && value.endsWith(']')) {
          try {
            final dynamic msg =
                jsonDecode(value.substring(1, value.length - 1));
            if (msg is Map) {
              _handleBrowserMessage(msg);
            }
          } catch (_) {
            // ignore
          }
        }
      }
    });
  }

  final ChromeTab tab;

  RemoteObject _remote;

  Future<RemoteObject> getBrowserChannel() async {
    final DateTime start = DateTime.now();
    final DateTime end = start.add(const Duration(seconds: 30));

    while (true) {
      try {
        return await _getAppChannelObject();
      } catch (e) {
        if (end.isBefore(DateTime.now())) {
          final Duration duration = DateTime.now().difference(start);
          print('timeout getting the browser channel object ($duration)');
          rethrow;
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  Future<RemoteObject> _getAppChannelObject() {
    return tab.wipConnection.runtime.evaluate('devtools');
  }

  int _nextId = 1;

  final Map<int, Completer<AppResponse>> _completers =
      <int, Completer<AppResponse>>{};

  final StreamController<AppEvent> _eventStream =
      StreamController<AppEvent>.broadcast();

  Stream<AppEvent> get onEvent => _eventStream.stream;

  Future<AppResponse> send(String method, [dynamic params]) async {
    _remote ??= await _getAppChannelObject();

    final int id = _nextId++;

    final Completer<AppResponse> completer = Completer<AppResponse>();
    _completers[id] = completer;

    try {
      await tab.wipConnection.runtime.callFunctionOn(
        "function (method, id, params) { return window['devtools'].send(method, id, params); }",
        objectId: _remote.objectId,
        arguments: <dynamic>[method, id, params],
      );

      return completer.future;
    } catch (e, st) {
      _completers.remove(id);
      completer.completeError(e, st);
      rethrow;
    }
  }

  Future<void> close() async {
    await tab.wipConnection.target.closeTarget(tab.wipTab.id);
  }

  void _handleBrowserMessage(Map<dynamic, dynamic> message) {
    if (verboseTesting) {
      print(message);
    }

    if (message.containsKey('id')) {
      // handle a response: {id: 1}
      final AppResponse response = AppResponse(message);
      final Completer<AppResponse> completer = _completers.remove(response.id);
      if (response.hasError) {
        completer.completeError(response.error);
      } else {
        completer.complete(response);
      }
    } else {
      // handle an event: {event: app.echo, params: foo}
      _eventStream.add(AppEvent(message));
    }
  }
}

class AppEvent {
  AppEvent(this.json);

  final Map<dynamic, dynamic> json;

  String get event => json['event'];

  dynamic get params => json['params'];

  @override
  String toString() => '$event ${params ?? ''}';
}

class AppResponse {
  AppResponse(this.json);

  final Map<dynamic, dynamic> json;

  int get id => json['id'];

  dynamic get result => json['result'];

  bool get hasError => json.containsKey('error');

  AppError get error => AppError(json['error']);

  @override
  String toString() {
    return hasError ? error.toString() : result.toString();
  }
}

class AppError {
  AppError(this.json);

  final Map<dynamic, dynamic> json;

  String get message => json['message'];

  String get stackTrace => json['stackTrace'];

  @override
  String toString() => '$message\n$stackTrace';
}

class WebdevFixture {
  WebdevFixture._(this.process, this.url);

  static Future<WebdevFixture> create({bool verbose = false}) async {
    // 'pub run webdev serve web'

    // Remove the DART_VM_OPTIONS env variable from the child process, so the
    // Dart VM doesn't try and open a service protocol port if
    // 'DART_VM_OPTIONS: --enable-vm-service:63990' was passed in.
    final Map<String, String> environment =
        Map<String, String>.from(Platform.environment);
    if (environment.containsKey('DART_VM_OPTIONS')) {
      environment['DART_VM_OPTIONS'] = '';
    }

    final Process process = await Process.start(
      'pub',
      <String>['run', 'webdev', 'serve', 'web'],
      environment: environment,
    );

    final Stream<String> lines =
        process.stdout.transform(utf8.decoder).transform(const LineSplitter());
    final Completer<String> hasUrl = Completer<String>();

    lines.listen((String line) {
      if (verbose) {
        print('webdev • ${line.trim()}');
      }

      // Serving `web` on http://localhost:8080
      if (line.startsWith(r'Serving `web`')) {
        final String url = line.substring(line.indexOf('http://'));
        hasUrl.complete(url);
      }
    });

    final String url = await hasUrl.future;

    await delay();

    return WebdevFixture._(process, url);
  }

  final Process process;
  final String url;

  Uri get baseUri => Uri.parse(url);

  Future<void> teardown() async {
    process.kill();
  }
}
