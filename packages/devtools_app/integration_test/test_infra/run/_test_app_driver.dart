// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '_io_utils.dart';

// Set this to true for debugging to get JSON written to stdout.
const bool _printDebugOutputToStdOut = false;

class TestFlutterApp extends _TestApp {
  TestFlutterApp({String appPath = 'test/test_infra/fixtures/flutter_app'})
      : super(appPath);

  @override
  Future<void> startProcess() async {
    runProcess = await Process.start(
      'flutter',
      [
        'run',
        '--machine',
        '-d',
        'flutter-tester',
      ],
      workingDirectory: testAppPath,
    );
  }
}

// TODO(kenz): implement for running integration tests against a Dart CLI app.
class TestDartCliApp {}

abstract class _TestApp with IOMixin {
  _TestApp(this.testAppPath);

  static const _appStartTimeout = Duration(seconds: 120);

  static const _defaultTimeout = Duration(seconds: 40);

  static const _quitTimeout = Duration(seconds: 10);

  /// The path relative to the 'devtools_app' directory where the test app
  /// lives.
  ///
  /// This will either be a file path or a directory path depending on the type
  /// of app.
  final String testAppPath;

  late Process? runProcess;

  late int runProcessId;

  final _allMessages = StreamController<String>.broadcast();

  Uri get vmServiceUri => _vmServiceWsUri;
  late Uri _vmServiceWsUri;

  String? _currentRunningAppId;

  Future<void> startProcess();

  Future<void> start() async {
    await startProcess();
    assert(
      runProcess != null,
      '\'runProcess\' cannot be null. Assign \'runProcess\' inside the '
      '\'startProcess\' method.',
    );

    // This class doesn't use the result of the future. It's made available
    // via a getter for external uses.
    unawaited(
      runProcess!.exitCode.then((int code) {
        _debugPrint('Process exited ($code)');
      }),
    );

    listenToProcessOutput(runProcess!, printCallback: _debugPrint);

    // Stash the PID so that we can terminate the VM more reliably than using
    // proc.kill() (because proc is a shell, because `flutter` is a shell
    // script).
    final connected =
        await waitFor(event: FlutterDaemonConstants.daemonConnected.key);
    runProcessId = (connected[FlutterDaemonConstants.params.key]!
        as Map<String, Object?>)[FlutterDaemonConstants.pid.key] as int;

    // Set this up now, but we don't await it yet. We want to make sure we don't
    // miss it while waiting for debugPort below.
    final started = waitFor(
      event: FlutterDaemonConstants.appStarted.key,
      timeout: _appStartTimeout,
    );

    final debugPort = await waitFor(
      event: FlutterDaemonConstants.appDebugPort.key,
      timeout: _appStartTimeout,
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

  Future<int> stop() async {
    if (_currentRunningAppId != null) {
      _debugPrint('Stopping app');
      await Future.any<void>(<Future<void>>[
        runProcess!.exitCode,
        _sendRequest(
          'app.stop',
          <String, dynamic>{'appId': _currentRunningAppId},
        ),
      ]).timeout(
        _quitTimeout,
        onTimeout: () {
          _debugPrint('app.stop did not return within $_quitTimeout');
        },
      );
      _currentRunningAppId = null;
    }

    _debugPrint('Waiting for process to end');
    return runProcess!.exitCode.timeout(
      _quitTimeout,
      onTimeout: _killGracefully,
    );
  }

  int _requestId = 1;
  Future<dynamic> _sendRequest(String method, dynamic params) async {
    final int requestId = _requestId++;
    final Map<String, dynamic> request = <String, dynamic>{
      'id': requestId,
      'method': method,
      'params': params,
    };
    final String jsonEncoded = json.encode(<Map<String, dynamic>>[request]);
    _debugPrint(jsonEncoded);

    // Set up the response future before we send the request to avoid any
    // races. If the method we're calling is app.stop then we tell waitFor not
    // to throw if it sees an app.stop event before the response to this request.
    final Future<Map<String, dynamic>> responseFuture = waitFor(
      id: requestId,
      ignoreAppStopEvent: method == 'app.stop',
    );
    runProcess!.stdin.writeln(jsonEncoded);
    final Map<String, dynamic> response = await responseFuture;

    if (response['error'] != null || response['result'] == null) {
      throw Exception('Unexpected error response');
    }

    return response['result'];
  }

  Future<int> _killGracefully() async {
    _debugPrint('Sending SIGTERM to $runProcessId..');
    await cancelAllStreamSubscriptions();
    Process.killPid(runProcessId);
    return runProcess!.exitCode
        .timeout(_quitTimeout, onTimeout: _killForcefully);
  }

  Future<int> _killForcefully() {
    // Use sigint here instead of sigkill. See
    // https://github.com/flutter/flutter/issues/117415.
    _debugPrint('Sending SIGINT to $runProcessId..');
    Process.killPid(runProcessId, ProcessSignal.sigint);
    return runProcess!.exitCode;
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
      final int ms = DateTime.now().difference(start).inMilliseconds;
      messages.writeln('[+ ${ms.toString().padLeft(5)}] $m');
    }

    final sub = _allMessages.stream.listen(logMessage);

    return f().timeout(
      timeout ?? _defaultTimeout,
      onTimeout: () {
        logMessage('<timed out>');
        throw '$message';
      },
    ).catchError((error) {
      throw '$error\nReceived:\n${messages.toString()}';
    }).whenComplete(() => sub.cancel());
  }

  Map<String, Object?>? _parseFlutterResponse(String line) {
    if (line.startsWith('[') && line.endsWith(']')) {
      try {
        final Map<String, Object?>? resp = json.decode(line)[0];
        return resp;
      } catch (e) {
        // Not valid JSON, so likely some other output that was surrounded by [brackets]
        return null;
      }
    }
    return null;
  }

  String _debugPrint(String msg) {
    const maxLength = 500;
    final truncatedMsg =
        msg.length > maxLength ? msg.substring(0, maxLength) + '...' : msg;
    _allMessages.add(truncatedMsg);
    if (_printDebugOutputToStdOut) {
      print('$truncatedMsg');
    }
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
