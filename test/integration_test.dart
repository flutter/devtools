// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart'
    show RemoteObject, ConsoleAPIEvent;

import 'app_fixture.dart';
import 'src/chrome.dart';

WebdevFixture webdevFixture;
BrowserManager browserManager;

const bool verboseTesting = false;

void main() {
  group('integration', () {
    setUpAll(() async {
      webdevFixture = await WebdevFixture.create();
      browserManager = await BrowserManager.create();
    });

    tearDownAll(() async {
      await browserManager?.teardown();
      await webdevFixture?.teardown();
    });

    group('app', appTests);
    group('logging', loggingTests);
  }, timeout: const Timeout.factor(2));
}

void appTests() {
  CliAppFixture appFixture;
  BrowserTabInstance tabInstance;

  setUp(() async {
    appFixture = await CliAppFixture.create('test/fixtures/logging_app.dart');
    tabInstance = await browserManager.createNewTab();
  });

  tearDown(() async {
    await tabInstance?.close();
    await appFixture?.teardown();
  });

  test('can switch pages', () async {
    final DevtoolsManager tools = new DevtoolsManager(tabInstance);
    await tools.start(appFixture);
    await tools.switchPage('logs');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'logs');
  });
}

void loggingTests() {
  CliAppFixture appFixture;
  BrowserTabInstance tabInstance;

  setUp(() async {
    appFixture = await CliAppFixture.create('test/fixtures/logging_app.dart');
    tabInstance = await browserManager.createNewTab();
  });

  tearDown(() async {
    await tabInstance?.close();
    await appFixture?.teardown();
  });

  test('displays log data', () async {
    final DevtoolsManager tools = new DevtoolsManager(tabInstance);
    await tools.start(appFixture);
    await tools.switchPage('logs');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'logs');

    // Cause app to log.
    final LoggingManager logs = tools.loggingManager;
    await logs.clearLogs();
    expect(await logs.logCount(), 0);
    await appFixture.invoke('controller.emitLog()');

    // Verify the log data shows up in the UI.
    // TODO(devoncarew): Instead of a fixed delay, poll some amount of time for
    // a predicate value.
    await new Future<dynamic>.delayed(const Duration(milliseconds: 200));
    expect(await logs.logCount(), greaterThan(0));
  });
}

class DevtoolsManager {
  DevtoolsManager(this.tabInstance);

  final BrowserTabInstance tabInstance;

  LoggingManager _loggingManager;

  Future<void> start(AppFixture appFixture) async {
    final Uri baseAppUri = webdevFixture.baseUri
        .resolve('index.html?port=${appFixture.servicePort}');
    await tabInstance.tab.navigate(baseAppUri.toString());

    // wait for app initialization
    await tabInstance.getBrowserChannel();
  }

  LoggingManager get loggingManager =>
      _loggingManager ??= new LoggingManager(this);

  Future<void> switchPage(String page) async {
    await tabInstance.send('switchPage', page);
  }

  Future<String> currentPageId() async {
    final AppResponse response = await tabInstance.send('currentPageId');
    return response.result;
  }
}

class LoggingManager {
  LoggingManager(this.tools);

  final DevtoolsManager tools;

  Future<void> clearLogs() async {
    await tools.tabInstance.send('logs.clearLogs');
  }

  Future<int> logCount() async {
    final AppResponse response = await tools.tabInstance.send('logs.logCount');
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

    return new BrowserManager._(chromeProcess, tab);
  }

  final ChromeProcess chromeProcess;
  final ChromeTab tab;

  Future<BrowserTabInstance> createNewTab() async {
    final String targetId = await this.tab.createNewTarget();

    final ChromeTab tab =
        await chromeProcess.connectToTabId('localhost', targetId);
    await tab.connect();

    await tab.wipConnection.target.activateTarget(targetId);

    return new BrowserTabInstance(tab);
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

  Future<RemoteObject> getBrowserChannel({
    Duration retryFor = const Duration(seconds: 20),
  }) async {
    final DateTime start = new DateTime.now();
    DateTime end = start;
    if (retryFor != null) {
      end = start.add(retryFor);
    }

    while (true) {
      try {
        return await _getAppChannelObject();
      } catch (e) {
        if (end.isBefore(new DateTime.now())) {
          rethrow;
        }
      }
      await new Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  Future<RemoteObject> _getAppChannelObject() {
    return tab.wipConnection.runtime.evaluate('devtools');
  }

  int _nextId = 1;

  final Map<int, Completer<AppResponse>> _completers =
      <int, Completer<AppResponse>>{};

  final StreamController<AppEvent> _eventStream =
      new StreamController<AppEvent>.broadcast();

  Stream<AppEvent> get onEvent => _eventStream.stream;

  Future<AppResponse> send(String method, [dynamic params]) async {
    _remote ??= await _getAppChannelObject();

    final int id = _nextId++;

    final Completer<AppResponse> completer = new Completer<AppResponse>();
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
      final AppResponse response = new AppResponse(message);
      final Completer<AppResponse> completer = _completers.remove(response.id);
      if (response.hasError) {
        completer.completeError(response.error);
      } else {
        completer.complete(response);
      }
    } else {
      // handle an event: {event: app.echo, params: foo}
      _eventStream.add(new AppEvent(message));
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

  AppError get error => new AppError(json['error']);

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

  static Future<WebdevFixture> create() async {
    // 'pub run webdev serve web'
    final Process process = await Process.start(
      'pub',
      <String>['run', 'webdev', 'serve', 'web'],
    );

    final Stream<String> lines =
        process.stdout.transform(utf8.decoder).transform(const LineSplitter());
    final Completer<String> hasUrl = new Completer<String>();

    lines.listen((String line) {
      print(line.trim());

      // Serving `web` on http://localhost:8080
      if (line.startsWith(r'Serving `web`')) {
        final String url = line.substring(line.indexOf('http://'));
        hasUrl.complete(url);
      }
    });

    final String url = await hasUrl.future;

    return new WebdevFixture._(process, url);
  }

  final Process process;
  final String url;

  Uri get baseUri => Uri.parse(url);

  Future<void> teardown() async {
    process.kill();
  }
}
