// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

@TestOn('vm')
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_shared/devtools_test_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart'
    show ConsoleAPIEvent, RemoteObject;

const bool verboseTesting = false;

late WebBuildFixture webBuildFixture;
late BrowserManager browserManager;

class DevtoolsManager {
  DevtoolsManager(this.tabInstance, this.baseUri);

  final BrowserTabInstance tabInstance;
  final Uri baseUri;

  Future<void> start(
    AppFixture appFixture, {
    Uri? overrideUri,
    bool waitForConnection = true,
  }) async {
    final Uri baseAppUri = baseUri.resolve(
      'index.html?uri=${Uri.encodeQueryComponent(appFixture.serviceUri.toString())}',
    );
    await tabInstance.tab.navigate('${overrideUri ?? baseAppUri}');

    // wait for app initialization
    await Future.wait([
      waitForConnection
          ? tabInstance.onEvent
              .firstWhere((msg) => msg.event == 'app.devToolsReady')
          : Future<void>.value(),
      tabInstance.getBrowserChannel(),
    ]);
  }

  Future<void> switchPage(String page) async {
    await tabInstance.send('switchPage', page);
  }

  Future<String?> currentPageId() async {
    final AppResponse response = await tabInstance.send('currentPageId');
    return response.result as String?;
  }
}

class BrowserManager {
  BrowserManager._(this.chromeProcess, this.tab);

  static Future<BrowserManager> create() async {
    final Chrome? chrome = Chrome.locate();
    if (chrome == null) {
      throw 'unable to locate Chrome';
    }

    final ChromeProcess chromeProcess = await chrome.start();
    final ChromeTab tab = (await chromeProcess.getFirstTab())!;

    await tab.connect();

    return BrowserManager._(chromeProcess, tab);
  }

  final ChromeProcess chromeProcess;
  final ChromeTab tab;

  Future<BrowserTabInstance> createNewTab() async {
    final String targetId = await this.tab.createNewTarget();

    await delay();

    final ChromeTab tab =
        (await chromeProcess.connectToTabId('localhost', targetId))!;
    await tab.connect(verbose: true);

    await delay();

    await tab.wipConnection!.target.activateTarget(targetId);

    await delay();

    return BrowserTabInstance(tab);
  }

  void teardown() {
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
            final msg = jsonDecode(value.substring(1, value.length - 1));
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

  RemoteObject? _remote;

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
    return tab.wipConnection!.runtime.evaluate('devtools');
  }

  int _nextId = 1;

  final Map<int, Completer<AppResponse>> _completers =
      <int, Completer<AppResponse>>{};

  final StreamController<AppEvent> _eventStream =
      StreamController<AppEvent>.broadcast();

  Stream<AppEvent> get onEvent => _eventStream.stream;

  Future<AppResponse> send(String method, [Object? params]) async {
    _remote ??= await _getAppChannelObject();

    final int id = _nextId++;

    final Completer<AppResponse> completer = Completer<AppResponse>();
    _completers[id] = completer;

    try {
      await tab.wipConnection!.runtime.callFunctionOn(
        "function (method, id, params) { return window['devtools'].send(method, id, params); }",
        objectId: _remote!.objectId,
        arguments: <Object?>[method, id, params],
      );

      return completer.future;
    } catch (e, st) {
      _completers.remove(id);
      completer.completeError(e, st);
      rethrow;
    }
  }

  Future<void> close() async {
    // In Headless Chrome, we get Inspector.detached when we close the last
    // target rather than a response.
    await Future.any(<Future<Object>>[
      tab.wipConnection!.onNotification
          .firstWhere((n) => n.method == 'Inspector.detached'),
      tab.wipConnection!.target.closeTarget(tab.wipTab.id),
    ]);
  }

  void _handleBrowserMessage(Map<dynamic, dynamic> message) {
    if (verboseTesting) {
      print(message);
    }

    if (message.containsKey('id')) {
      // handle a response: {id: 1}
      final AppResponse response = AppResponse(message);
      final Completer<AppResponse> completer = _completers.remove(response.id)!;
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

  String? get event => json['event'];

  Object? get params => json['params'];

  @override
  String toString() => '$event ${params ?? ''}';
}

class AppResponse {
  AppResponse(this.json);

  final Map<dynamic, dynamic> json;

  int? get id => json['id'];

  Object? get result => json['result'];

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

  String? get message => json['message'];

  String? get stackTrace => json['stackTrace'];

  @override
  String toString() => '$message\n$stackTrace';
}

class WebBuildFixture {
  WebBuildFixture._(this.process, this.url, this.verbose);

  static Future<WebBuildFixture> serve({
    bool release = false,
    bool verbose = false,
  }) async {
    final List<String> cliArgs = [
      'pub',
      'run',
      'build_runner',
      'serve',
      'web',
      '--delete-conflicting-outputs',
    ];
    if (release) {
      cliArgs.add('--release');
    }

    final process = await _runFlutter(cliArgs);

    final Completer<String> hasUrl = Completer<String>();

    _toLines(process.stderr).listen((String line) {
      if (verbose || hasUrl.isCompleted) {
        print(
          'pub run build_runner serve • ${process.pid}'
          ' • STDERR • ${line.trim()}',
        );
      }

      final err = 'error starting webdev: $line';
      if (!hasUrl.isCompleted) {
        hasUrl.completeError(err);
      } else {
        print('Ignoring stderr output because already completed');
      }
    });

    _toLines(process.stdout).listen((String line) {
      if (verbose) {
        print('pub run build_runner serve • ${process.pid} • ${line.trim()}');
      }

      // Serving `web` on http://localhost:8080
      if (line.contains('Serving `web`')) {
        hasUrl.safeComplete(
          line.substring(line.indexOf('http://')),
          () => print(
            'Ignoring "Serving..." notification because already completed',
          ),
        );
      }
    });

    final String url = await hasUrl.future;

    await delay();

    return WebBuildFixture._(process, url, verbose);
  }

  static Future<void> build({
    bool verbose = false,
  }) async {
    final clean = await _runFlutter(['clean']);
    expect(await clean.exitCode, 0);
    final pubGet = await _runFlutter(['pub', 'get']);
    expect(await pubGet.exitCode, 0);

    final List<String> cliArgs = [];
    String commandName;
    commandName = 'flutter build web';
    cliArgs.addAll([
      'build',
      'web',
      '--pwa-strategy=none',
      '--dart-define=FLUTTER_WEB_USE_SKIA=true',
      '--no-tree-shake-icons',
    ]);

    final process = await _runFlutter(cliArgs, verbose: verbose);

    final Completer<void> buildFinished = Completer<void>();

    _toLines(process.stderr).listen((String line) {
      // TODO(https://github.com/flutter/devtools/issues/2477): this is a
      // work around for an expected warning that would otherwise fail the test.
      if (line.toLowerCase().contains('warning')) {
        return;
      }
      if (line.toLowerCase().contains(' from path ../devtools_')) {
        return;
      }

      final err = 'error building flutter: $line';
      if (!buildFinished.isCompleted) {
        buildFinished.completeError(err);
      } else {
        print(err);
      }
    });

    _toLines(process.stdout).listen((String line) {
      if (verbose) {
        print('$commandName • ${line.trim()}');
      }

      if (!buildFinished.isCompleted) {
        if (line.contains('[INFO] Succeeded')) {
          buildFinished.complete();
        } else if (line.contains('[SEVERE]')) {
          buildFinished.completeError(line);
        }
      }
    });

    unawaited(
      process.exitCode.then((code) {
        if (!buildFinished.isCompleted) {
          if (code == 0) {
            buildFinished.complete();
          } else {
            buildFinished.completeError('Exited with code $code');
          }
        }
      }),
    );

    await buildFinished.future.catchError((Object? e) {
      fail('Build failed: $e');
    });

    await process.exitCode;
  }

  final Process process;
  final String url;
  final bool verbose;

  Uri get baseUri => Uri.parse(url);

  Future<void> teardown() async {
    process.kill();
    final exitCode = await process.exitCode;
    if (verbose) {
      print('flutter exited with code $exitCode');
    }
  }

  static Future<Process> _runFlutter(
    List<String> buildArgs, {
    bool verbose = false,
  }) {
    // Remove the DART_VM_OPTIONS env variable from the child process, so the
    // Dart VM doesn't try and open a service protocol port if
    // 'DART_VM_OPTIONS: --enable-vm-service:63990' was passed in.
    final Map<String, String> environment =
        Map<String, String>.from(Platform.environment);
    if (environment.containsKey('DART_VM_OPTIONS')) {
      environment['DART_VM_OPTIONS'] = '';
    }

    // TODO(https://github.com/flutter/devtools/issues/1145): The pub-based
    // version of this code would run a pub snapshot instead of starting pub
    // directly to prevent Windows-based test runs getting killed but leaving
    // the pub process behind. Something similar might be needed here.
    // See here for more information:
    // https://github.com/flutter/flutter/wiki/The-flutter-tool#debugging-the-flutter-command-line-tool
    final executable = Platform.isWindows ? 'flutter.bat' : 'flutter';

    if (verbose) {
      print(
        'Running "$executable" with args: ${buildArgs.join(' ')} from ${Directory.current.path}',
      );
    }
    return Process.start(
      executable,
      buildArgs,
      environment: environment,
      workingDirectory: Directory.current.path,
    );
  }

  static Stream<String> _toLines(Stream<List<int>> stream) =>
      stream.transform(utf8.decoder).transform(const LineSplitter());
}
