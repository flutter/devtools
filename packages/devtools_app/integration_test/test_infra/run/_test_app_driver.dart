// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:devtools_shared/devtools_test_utils.dart';

import '_utils.dart';

class TestFlutterApp extends IntegrationTestApp {
  TestFlutterApp({
    String appPath = 'test/test_infra/fixtures/flutter_app',
    TestAppDevice appDevice = TestAppDevice.flutterTester,
  }) : super(appPath, appDevice);

  String? _currentRunningAppId;

  @override
  Future<void> startProcess() async {
    runProcess = await Process.start(
      'flutter',
      [
        'run',
        '--machine',
        '-d',
        testAppDevice.argName,
        // Do not serve DevTools from Flutter Tools.
        '--no-devtools',
      ],
      workingDirectory: testAppPath,
    );
  }

  @override
  Future<void> waitForAppStart() async {
    // Set this up now, but we don't await it yet. We want to make sure we don't
    // miss it while waiting for debugPort below.
    final started = waitFor(
      event: FlutterDaemonConstants.appStarted.key,
      timeout: IntegrationTestApp._appStartTimeout,
    );

    final debugPort = await waitFor(
      event: FlutterDaemonConstants.appDebugPort.key,
      timeout: IntegrationTestApp._appStartTimeout,
    );
    final wsUriString = (debugPort[FlutterDaemonConstants.params.key]!
        as Map<String, Object?>)[FlutterDaemonConstants.wsUri.key] as String;
    _vmServiceWsUri = Uri.parse(wsUriString);

    // Map to WS URI.
    _vmServiceWsUri =
        convertToWebSocketUrl(serviceProtocolUrl: _vmServiceWsUri);

    // Now await the started event; if it had already happened the future will
    // have already completed.
    final startedResult = await started;
    final params = startedResult[FlutterDaemonConstants.params.key]!
        as Map<String, Object?>;
    _currentRunningAppId = params[FlutterDaemonConstants.appId.key] as String?;
  }

  @override
  Future<void> manuallyStopApp() async {
    if (_currentRunningAppId != null) {
      _debugPrint('Stopping app');
      await Future.any<void>(<Future<void>>[
        runProcess!.exitCode,
        _sendFlutterDaemonRequest(
          'app.stop',
          <String, dynamic>{'appId': _currentRunningAppId},
        ),
      ]).timeout(
        IOMixin.killTimeout,
        onTimeout: () {
          _debugPrint('app.stop did not return within ${IOMixin.killTimeout}');
        },
      );
      _currentRunningAppId = null;
    }
  }

  int _requestId = 1;
  // ignore: avoid-dynamic, dynamic by design.
  Future<dynamic> _sendFlutterDaemonRequest(
    String method,
    Object? params,
  ) async {
    final requestId = _requestId++;
    final request = <String, dynamic>{
      'id': requestId,
      'method': method,
      'params': params,
    };
    final jsonEncoded = json.encode(<Map<String, dynamic>>[request]);
    _debugPrint(jsonEncoded);

    // Set up the response future before we send the request to avoid any
    // races. If the method we're calling is app.stop then we tell waitFor not
    // to throw if it sees an app.stop event before the response to this request.
    final responseFuture = waitFor(
      id: requestId,
      ignoreAppStopEvent: method == 'app.stop',
    );
    runProcess!.stdin.writeln(jsonEncoded);
    final response = await responseFuture;

    if (response['error'] != null || response['result'] == null) {
      throw Exception('Unexpected error response');
    }

    return response['result'];
  }

  Future<Map<String, Object?>> waitFor({
    String? event,
    int? id,
    Duration? timeout,
    bool ignoreAppStopEvent = false,
  }) {
    final response = Completer<Map<String, Object?>>();
    late StreamSubscription<String> sub;
    sub = stdoutController.stream.listen(
      (String line) => _handleStdout(
        line,
        subscription: sub,
        response: response,
        event: event,
        id: id,
        ignoreAppStopEvent: ignoreAppStopEvent,
      ),
    );

    return _timeoutWithMessages<Map<String, Object?>>(
      () => response.future,
      timeout: timeout,
      message: event != null
          ? 'Did not receive expected $event event.'
          : 'Did not receive response to request "$id".',
    ).whenComplete(() => sub.cancel());
  }

  void _handleStdout(
    String line, {
    required StreamSubscription<String> subscription,
    required Completer<Map<String, Object?>> response,
    required String? event,
    required int? id,
    bool ignoreAppStopEvent = false,
  }) async {
    final json = _parseFlutterResponse(line);
    if (json == null) {
      return;
    } else if ((event != null &&
            json[FlutterDaemonConstants.event.key] == event) ||
        (id != null && json[FlutterDaemonConstants.id.key] == id)) {
      await subscription.cancel();
      response.complete(json);
    } else if (!ignoreAppStopEvent &&
        json[FlutterDaemonConstants.event.key] ==
            FlutterDaemonConstants.appStop.key) {
      await subscription.cancel();
      final error = StringBuffer();
      error.write('Received app.stop event while waiting for ');
      error.write(
        '${event != null ? '$event event' : 'response to request $id.'}.\n\n',
      );
      final errorFromJson = (json[FlutterDaemonConstants.params.key]
          as Map<String, Object?>?)?[FlutterDaemonConstants.error.key];
      if (errorFromJson != null) {
        error.write('$errorFromJson\n\n');
      }
      final traceFromJson = (json[FlutterDaemonConstants.params.key]
          as Map<String, Object?>?)?[FlutterDaemonConstants.trace.key];
      if (traceFromJson != null) {
        error.write('$traceFromJson\n\n');
      }
      response.completeError(error.toString());
    }
  }

  Map<String, Object?>? _parseFlutterResponse(String line) {
    if (line.startsWith('[') && line.endsWith(']')) {
      try {
        return (json.decode(line) as List)[0];
      } catch (e) {
        // Not valid JSON, so likely some other output that was surrounded by
        // [brackets].
        return null;
      }
    }
    return null;
  }
}

class TestDartCliApp extends IntegrationTestApp {
  TestDartCliApp({
    String appPath = 'test/test_infra/fixtures/empty_app.dart',
  }) : super(appPath, TestAppDevice.cli);

  static const vmServicePrefix = 'The Dart VM service is listening on ';

  @override
  Future<void> startProcess() async {
    const separator = '/';
    final parts = testAppPath.split(separator);
    final scriptName = parts.removeLast();
    final workingDir = parts.join(separator);
    runProcess = await Process.start(
      'dart',
      [
        '--observe=0',
        'run',
        scriptName,
      ],
      workingDirectory: workingDir,
    );
  }

  @override
  Future<void> waitForAppStart() async {
    final vmServiceUri = await waitFor(
      message: vmServicePrefix,
      timeout: IntegrationTestApp._appStartTimeout,
    );
    final parsedVmServiceUri = Uri.parse(vmServiceUri);

    // Map to WS URI.
    _vmServiceWsUri =
        convertToWebSocketUrl(serviceProtocolUrl: parsedVmServiceUri);
  }

  Future<String> waitFor({required String message, Duration? timeout}) {
    final response = Completer<String>();
    late StreamSubscription<String> sub;
    sub = stdoutController.stream.listen(
      (String line) => _handleStdout(
        line,
        subscription: sub,
        response: response,
        message: message,
      ),
    );

    return _timeoutWithMessages<String>(
      () => response.future,
      timeout: timeout,
      message: 'Did not receive expected message: $message.',
    ).whenComplete(() => sub.cancel());
  }

  void _handleStdout(
    String line, {
    required StreamSubscription<String> subscription,
    required Completer<String> response,
    required String message,
  }) async {
    if (message == vmServicePrefix && line.startsWith(vmServicePrefix)) {
      final vmServiceUri = line
          .substring(line.indexOf(vmServicePrefix) + vmServicePrefix.length);
      await subscription.cancel();
      response.complete(vmServiceUri);
    }
  }
}

abstract class IntegrationTestApp with IOMixin {
  IntegrationTestApp(this.testAppPath, this.testAppDevice);

  static const _appStartTimeout = Duration(seconds: 240);

  static const _defaultTimeout = Duration(seconds: 40);

  /// The path relative to the 'devtools_app' directory where the test app
  /// lives.
  ///
  /// This will either be a file path or a directory path depending on the type
  /// of app.
  final String testAppPath;

  /// The device the test app should run on, e.g. flutter-tester, chrome.
  final TestAppDevice testAppDevice;

  late Process? runProcess;

  int get runProcessId => runProcess!.pid;

  final _allMessages = StreamController<String>.broadcast();

  Uri get vmServiceUri => _vmServiceWsUri;
  late Uri _vmServiceWsUri;

  Future<void> startProcess();

  Future<void> waitForAppStart();

  Future<void> manuallyStopApp() async {}

  Future<void> start() async {
    _debugPrint('starting the test app process for $testAppPath');
    await startProcess();
    assert(
      runProcess != null,
      '\'runProcess\' cannot be null. Assign \'runProcess\' inside the '
      '\'startProcess\' method.',
    );
    _debugPrint('process started (pid $runProcessId)');

    // This class doesn't use the result of the future. It's made available
    // via a getter for external uses.
    unawaited(
      runProcess!.exitCode.then((int code) {
        _debugPrint('Process exited ($code)');
      }),
    );

    listenToProcessOutput(runProcess!, printCallback: _debugPrint);

    _debugPrint('waiting for app start...');
    await waitForAppStart();
  }

  Future<int> stop({Future<int>? onTimeout}) async {
    await manuallyStopApp();
    _debugPrint('Waiting for process to end');
    return runProcess!.exitCode.timeout(
      IOMixin.killTimeout,
      onTimeout: () => killGracefully(
        runProcess!,
        debugLogging: debugTestScript,
      ),
    );
  }

  Future<T> _timeoutWithMessages<T>(
    Future<T> Function() f, {
    Duration? timeout,
    String? message,
  }) {
    // Capture output to a buffer so if we don't get the response we want we can show
    // the output that did arrive in the timeout error.
    final messages = StringBuffer();
    final start = DateTime.now();
    void logMessage(String m) {
      final ms = DateTime.now().difference(start).inMilliseconds;
      messages.writeln('[+ ${ms.toString().padLeft(5)}] $m');
    }

    final sub = _allMessages.stream.listen(logMessage);

    return f().timeout(
      timeout ?? _defaultTimeout,
      onTimeout: () {
        logMessage('<timed out>');
        throw '$message';
      },
    ).catchError((Object? error) {
      throw '$error\nReceived:\n${messages.toString()}';
    }).whenComplete(() => sub.cancel());
  }

  String _debugPrint(String msg) {
    const maxLength = 500;
    final truncatedMsg =
        msg.length > maxLength ? '${msg.substring(0, maxLength)}...' : msg;
    _allMessages.add(truncatedMsg);
    debugLog('_TestApp - $truncatedMsg');
    return msg;
  }
}

/// Map the URI to a WebSocket URI for the VM service protocol.
///
/// If the URI is already a VM Service WebSocket URI it will not be modified.
Uri convertToWebSocketUrl({required Uri serviceProtocolUrl}) {
  final isSecure = serviceProtocolUrl.isScheme('wss') ||
      serviceProtocolUrl.isScheme('https');
  final scheme = isSecure ? 'wss' : 'ws';

  final path = serviceProtocolUrl.path.endsWith('/ws')
      ? serviceProtocolUrl.path
      : (serviceProtocolUrl.path.endsWith('/')
          ? '${serviceProtocolUrl.path}ws'
          : '${serviceProtocolUrl.path}/ws');

  return serviceProtocolUrl.replace(scheme: scheme, path: path);
}

// TODO(kenz): consider moving these constants to devtools_shared if they are
// used outside of these integration tests. Optionally, we could consider making
// these constants where the flutter daemon is defined in flutter tools.
enum FlutterDaemonConstants {
  event,
  error,
  id,
  appId,
  params,
  trace,
  wsUri,
  pid,
  appStop(nameOverride: 'app.stop'),
  appStarted(nameOverride: 'app.started'),
  appDebugPort(nameOverride: 'app.debugPort'),
  daemonConnected(nameOverride: 'daemon.connected');

  const FlutterDaemonConstants({String? nameOverride})
      : _nameOverride = nameOverride;

  final String? _nameOverride;

  String get key => _nameOverride ?? name;
}

enum TestAppDevice {
  flutterTester('flutter-tester'),
  flutterChrome('chrome'),
  cli('cli');

  const TestAppDevice(this.argName);

  final String argName;

  /// A mapping of test app device to the unsupported tests for that device.
  static final _unsupportedTestsForDevice = <TestAppDevice, List<String>>{
    TestAppDevice.flutterTester: [],
    TestAppDevice.flutterChrome: [
      'eval_and_browse_test.dart',
      'perfetto_test.dart',
      'performance_screen_event_recording_test.dart',
      'service_connection_test.dart',
      'service_extensions_test.dart',
    ],
    TestAppDevice.cli: [
      'debugger_panel_test.dart',
      'eval_and_browse_test.dart',
      'eval_and_inspect_test.dart',
      'perfetto_test.dart',
      'performance_screen_event_recording_test.dart',
      'service_connection_test.dart',
      'service_extensions_test.dart',
    ],
  };

  static final _argNameToDeviceMap =
      TestAppDevice.values.fold(<String, TestAppDevice>{}, (map, device) {
    map[device.argName] = device;
    return map;
  });

  static TestAppDevice? fromArgName(String argName) {
    return _argNameToDeviceMap[argName];
  }

  bool supportsTest(String testPath) {
    final unsupportedTests = _unsupportedTestsForDevice[this] ?? [];
    return unsupportedTests
        .none((unsupportedTestPath) => testPath.endsWith(unsupportedTestPath));
  }
}
