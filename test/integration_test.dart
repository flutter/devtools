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
    group('debugging', debuggingTests);
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
    await waitFor(() async => await logs.logCount() > 0);
    expect(await logs.logCount(), greaterThan(0));
  });
}

// TODO(devoncarew): Split the debugger tests out to a separate file.

void debuggingTests() {
  CliAppFixture appFixture;
  BrowserTabInstance tabInstance;

  setUp(() async {
    tabInstance = await browserManager.createNewTab();
  });

  tearDown(() async {
    await tabInstance?.close();
    await appFixture?.teardown();
  });

  test('lists scripts', () async {
    appFixture = await CliAppFixture.create('test/fixtures/debugging_app.dart');

    final DevtoolsManager tools = new DevtoolsManager(tabInstance);
    await tools.start(appFixture);
    await tools.switchPage('debugger');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'debugger');

    final DebuggingManager debuggingManager = tools.debuggingManager;

    // Get the list of scripts.
    final List<String> scripts = await debuggingManager.getScripts();
    expect(scripts, isNotEmpty);
    expect(scripts, anyElement(endsWith(appFixture.appScriptPath)));
  });

  test('breakpoints, variables, resume', () async {
    appFixture = await CliAppFixture.create('test/fixtures/debugging_app.dart');

    final String source = appFixture.scriptSource;
    final List<int> breakpointLines =
        CliAppFixture.parseBreakpointLines(source);

    final DevtoolsManager tools = new DevtoolsManager(tabInstance);
    await tools.start(appFixture);
    await tools.switchPage('debugger');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'debugger');

    final DebuggingManager debuggingManager = tools.debuggingManager;

    // clear and verify breakpoints
    List<String> breakpoints = await debuggingManager.getBreakpoints();
    expect(breakpoints, isEmpty);

    // set and verify breakpoints
    for (int line in breakpointLines) {
      await debuggingManager.addBreakpoint(appFixture.appScriptPath, line);
    }

    breakpoints = await debuggingManager.getBreakpoints();
    expect(breakpoints, isNotEmpty);

    // wait for paused state
    await waitFor(() async => await debuggingManager.getState() == 'paused');

    await shortDelay();

    // verify location
    expect(
      await debuggingManager.getLocation(),
      endsWith('${appFixture.appScriptPath}:${breakpointLines.first}'),
    );

    // verify stack frame
    final List<String> frames = await debuggingManager.getCallStackFrames();
    expect(frames.length, greaterThan(2));
    expect(frames.sublist(0, 2), [
      'Cat.performAction:debugging_app.dart',
      'main.run.<anonymous closure>:debugging_app.dart',
    ]);

    // verify variables
    expect(
      await debuggingManager.getVariables(),
      unorderedEquals(['this:Cat', 'actionStr:catAction!']),
    );

    // resume
    await debuggingManager.clearBreakpoints();
    await debuggingManager.resume();

    // verify state resumed
    expect(await debuggingManager.getState(), 'running');
  });

  test('stepping, async step, async frames', () async {
    appFixture =
        await CliAppFixture.create('test/fixtures/debugging_app_async.dart');

    final String source = appFixture.scriptSource;
    final int breakpointLine =
        CliAppFixture.parseBreakpointLines(source).single;
    final List<int> steppingLines = CliAppFixture.parseSteppingLines(source);

    final DevtoolsManager tools = new DevtoolsManager(tabInstance);
    await tools.start(appFixture);
    await tools.switchPage('debugger');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'debugger');

    final DebuggingManager debuggingManager = tools.debuggingManager;

    // clear and verify breakpoints
    List<String> breakpoints = await debuggingManager.getBreakpoints();
    expect(breakpoints, isEmpty);

    // set and verify breakpoint
    await debuggingManager.addBreakpoint(
        appFixture.appScriptPath, breakpointLine);

    breakpoints = await debuggingManager.getBreakpoints();
    expect(breakpoints, hasLength(1));

    // wait for paused state
    await waitFor(() async => await debuggingManager.getState() == 'paused');

    await shortDelay();

    // verify location
    expect(
      await debuggingManager.getLocation(),
      endsWith('${appFixture.appScriptPath}:$breakpointLine'),
    );

    // test stepping
    for (int stepLine in steppingLines) {
      // step
      await debuggingManager.step();

      // wait for paused state
      await waitFor(() async => await debuggingManager.getState() == 'paused');

      await shortDelay();

      // verify location
      expect(
        await debuggingManager.getLocation(),
        endsWith('${appFixture.appScriptPath}:$stepLine'),
      );
    }

    // verify an async stack frame
    final List<String> frames = await debuggingManager.getCallStackFrames();
    expect(frames.length, greaterThan(4));
    expect(frames.sublist(0, 4), [
      'performAction:debugging_app_async.dart',
      '<async break>',
      'main.run.<anonymous closure>:debugging_app_async.dart',
      '<async break>',
    ]);

    // resume
    await debuggingManager.clearBreakpoints();
    await debuggingManager.resume();

    // verify state resumed
    expect(await debuggingManager.getState(), 'running');
  });

  test('break on exceptions', () async {
    appFixture = await CliAppFixture.create(
        'test/fixtures/debugging_app_exception.dart');

    final String source = appFixture.scriptSource;
    final int exceptionLine = CliAppFixture.parseExceptionLines(source).first;

    final DevtoolsManager tools = new DevtoolsManager(tabInstance);
    await tools.start(appFixture);
    await tools.switchPage('debugger');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'debugger');

    final DebuggingManager debuggingManager = tools.debuggingManager;

    // verify running state
    expect(await debuggingManager.getState(), 'running');

    // set break on exceptions mode
    await debuggingManager.setExceptionPauseMode('All');

    // wait for paused state
    await waitFor(() async => await debuggingManager.getState() == 'paused');

    await shortDelay();

    // verify location
    expect(
      await debuggingManager.getLocation(),
      endsWith('${appFixture.appScriptPath}:$exceptionLine'),
    );

    // verify locals, including the exception object
    expect(await debuggingManager.getVariables(), [
      '<exception>:StateError',
      'foo:2',
    ]);

    // resume
    await debuggingManager.setExceptionPauseMode('Unhandled');
    await debuggingManager.resume();

    // verify state resumed
    expect(await debuggingManager.getState(), 'running');
  });

  test('console output', () async {
    appFixture = await CliAppFixture.create(
        'test/fixtures/debugging_app_exception.dart');

    final DevtoolsManager tools = new DevtoolsManager(tabInstance);
    await tools.start(appFixture);
    await tools.switchPage('debugger');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'debugger');

    final DebuggingManager debuggingManager = tools.debuggingManager;

    // verify running state
    expect(await debuggingManager.getState(), 'running');

    // wait until there's console output
    await waitFor(
        () async => (await debuggingManager.getConsoleContents()).isNotEmpty);

    // verify the console contents
    expect(
      await debuggingManager.getConsoleContents(),
      contains('1\n'),
    );
  });
}

Future<void> waitFor(
  Future<bool> condition(), {
  Duration timeout = const Duration(seconds: 4),
}) async {
  final DateTime end = new DateTime.now().add(timeout);

  while (!end.isBefore(new DateTime.now())) {
    if (await condition()) {
      return;
    }

    await shortDelay();
  }

  throw 'condition not satisfied';
}

Future shortDelay() {
  return new Future.delayed(const Duration(milliseconds: 100));
}

class DevtoolsManager {
  DevtoolsManager(this.tabInstance);

  final BrowserTabInstance tabInstance;

  LoggingManager _loggingManager;
  DebuggingManager _debuggingManager;

  Future<void> start(AppFixture appFixture) async {
    final Uri baseAppUri = webdevFixture.baseUri
        .resolve('index.html?port=${appFixture.servicePort}');
    await tabInstance.tab.navigate(baseAppUri.toString());

    // wait for app initialization
    await tabInstance.getBrowserChannel();
  }

  LoggingManager get loggingManager =>
      _loggingManager ??= new LoggingManager(this);

  DebuggingManager get debuggingManager =>
      _debuggingManager ??= new DebuggingManager(this);

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

class DebuggingManager {
  DebuggingManager(this.tools);

  final DevtoolsManager tools;

  Future<void> resume() async {
    await tools.tabInstance.send('debugger.resume');
  }

  Future<void> step() async {
    await tools.tabInstance.send('debugger.step');
  }

  Future<String> getLocation() async {
    final AppResponse response =
        await tools.tabInstance.send('debugger.getLocation');
    return response.result;
  }

  Future<List<String>> getVariables() async {
    final AppResponse response =
        await tools.tabInstance.send('debugger.getVariables');
    final List<dynamic> result = response.result;
    return result.cast<String>();
  }

  Future<String> getState() async {
    final AppResponse response =
        await tools.tabInstance.send('debugger.getState');
    return response.result;
  }

  Future<String> getConsoleContents() async {
    final AppResponse response =
        await tools.tabInstance.send('debugger.getConsoleContents');
    return response.result;
  }

  Future<void> clearBreakpoints() async {
    await tools.tabInstance.send('debugger.clearBreakpoints');
  }

  Future<void> addBreakpoint(String path, int line) async {
    await tools.tabInstance.send('debugger.addBreakpoint', [path, line]);
  }

  Future<void> setExceptionPauseMode(String mode) async {
    await tools.tabInstance.send('debugger.setExceptionPauseMode', mode);
  }

  Future<List<String>> getBreakpoints() async {
    final AppResponse response =
        await tools.tabInstance.send('debugger.getBreakpoints');
    final List<dynamic> result = response.result;
    return result.cast<String>();
  }

  Future<List<String>> getScripts() async {
    final AppResponse response =
        await tools.tabInstance.send('debugger.getScripts');
    final List<dynamic> result = response.result;
    return result.cast<String>();
  }

  Future<List<String>> getCallStackFrames() async {
    final AppResponse response =
        await tools.tabInstance.send('debugger.getCallStackFrames');
    final List<dynamic> result = response.result;
    return result.cast<String>();
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

    // Remove the DART_VM_OPTIONS env variable from the child process, so the
    // Dart VM doesn't try and open a service protocol port if
    // 'DART_VM_OPTIONS: --enable-vm-service:63990' was passed in.
    final Map<String, String> environment =
        new Map<String, String>.from(Platform.environment);
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
