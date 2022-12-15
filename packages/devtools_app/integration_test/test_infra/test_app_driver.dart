// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'io_utils.dart';

// Set this to true for debugging to get JSON written to stdout.
const bool _printDebugOutputToStdOut = true;

class TestFlutterApp extends _TestApp {
  TestFlutterApp({String appPath = 'test/test_infra/fixtures/flutter_app'})
      : super(appPath);

  Directory get workingDirectory => Directory(testAppPath);

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
    );
  }
}

// TODO implement.
class TestDartCliApp {}

abstract class _TestApp with IoMixin {
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

  final errorBuffer = StringBuffer();

  // VmServiceWrapper? vmService;

  Uri get vmServiceUri => _vmServiceWsUri;
  late Uri _vmServiceWsUri;

  final shutdownComplete = Completer<void>();

  bool hasExited = false;

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
        hasExited = true;
      }),
    );

    listenToProcessOutput(runProcess!, printCallback: _debugPrint);

    // Stash the PID so that we can terminate the VM more reliably than using
    // proc.kill() (because proc is a shell, because `flutter` is a shell
    // script).
    final Map<String, dynamic> connected =
        await waitFor(event: 'daemon.connected');
    runProcessId = connected['params']['pid'];

    // Set this up now, but we don't wait it yet. We want to make sure we don't
    // miss it while waiting for debugPort below.
    final Future<Map<String, dynamic>> started =
        waitFor(event: 'app.started', timeout: _appStartTimeout);

    final Map<String, dynamic> debugPort =
        await waitFor(event: 'app.debugPort', timeout: _appStartTimeout);
    final String wsUriString = debugPort['params']['wsUri'];
    _vmServiceWsUri = Uri.parse(wsUriString);

    // Map to WS URI.
    _vmServiceWsUri =
        convertToWebSocketUrl(serviceProtocolUrl: _vmServiceWsUri);

    //       vmService = VmServiceWrapper(
    //     await vmServiceConnectUri(_vmServiceWsUri.toString()),
    //     _vmServiceWsUri,
    //     trackFutures: true,
    //   );

    //   final vmServiceLocal = vmService!;
    //   vmServiceLocal.onSend.listen((String s) => _debugPrint('==> $s'));
    //   vmServiceLocal.onReceive.listen((String s) => _debugPrint('<== $s'));
    //   await Future.wait(<Future<Success>>[
    //     vmServiceLocal.streamListen(EventStreams.kIsolate),
    //     vmServiceLocal.streamListen(EventStreams.kDebug),
    //   ]);

    //   // On hot restarts, the isolate ID we have for the Flutter thread will
    //   // exit so we need to invalidate our cached ID.
    //   vmServiceLocal.onIsolateEvent.listen((Event event) {
    //     if (event.kind == EventKind.kIsolateExit &&
    //         event.isolate!.id == flutterIsolateId) {
    //       flutterIsolateId = null;
    //     }
    //   });

    //   // Because we start paused, resume so the app is in a "running" state as
    //   // expected by tests. Tests will reload/restart as required if they need
    //   // to hit breakpoints, etc.
    //   await waitForPause();
    //   if (runConfig.pauseOnExceptions) {
    //     await vmServiceLocal.setIsolatePauseMode(
    //       await getFlutterIsolateId(),
    //       exceptionPauseMode: ExceptionPauseMode.kUnhandled,
    //     );
    //   }
    //   await resume(wait: false);
    // }

    // Now await the started event; if it had already happened the future will
    // have already completed.
    // _currentRunningAppId = (await started)['params']['appId'];
    await started;
  }

  Future<int> killGracefully() async {
    _debugPrint('Sending SIGTERM to $runProcessId..');
    Process.killPid(runProcessId);

    final killFuture =
        runProcess!.exitCode.timeout(_quitTimeout, onTimeout: _killForcefully);
    unawaited(_killAndShutdown(killFuture));
    return killFuture;
  }

  Future<int> _killForcefully() async {
    _debugPrint('Sending SIGKILL to $runProcessId..');
    Process.killPid(runProcessId, ProcessSignal.sigkill);

    final killFuture = runProcess!.exitCode;
    unawaited(_killAndShutdown(killFuture));
    return killFuture;
  }

  Future<void> _killAndShutdown(Future<int> killFuture) async {
    unawaited(
      killFuture.then((_) async {
        await cancelAllStreamSubscriptions();
        shutdownComplete.complete();
      }),
    );
  }

  Future<Map<String, dynamic>> waitFor({
    String? event,
    int? id,
    Duration? timeout,
    bool ignoreAppStopEvent = false,
  }) async {
    final Completer<Map<String, dynamic>> response =
        Completer<Map<String, dynamic>>();
    late StreamSubscription<String> sub;
    sub = stdoutController.stream.listen((String line) async {
      final dynamic json = _parseFlutterResponse(line);
      if (json == null) {
        return;
      } else if ((event != null && json['event'] == event) ||
          (id != null && json['id'] == id)) {
        await sub.cancel();
        response.complete(json);
      } else if (!ignoreAppStopEvent && json['event'] == 'app.stop') {
        await sub.cancel();
        final StringBuffer error = StringBuffer();
        error.write('Received app.stop event while waiting for ');
        error.write(
          '${event != null ? '$event event' : 'response to request $id.'}.\n\n',
        );
        if (json['params'] != null && json['params']['error'] != null) {
          error.write('${json['params']['error']}\n\n');
        }
        if (json['params'] != null && json['params']['trace'] != null) {
          error.write('${json['params']['trace']}\n\n');
        }
        response.completeError(error.toString());
      }
    });

    return _timeoutWithMessages<Map<String, dynamic>>(
      () => response.future,
      timeout: timeout,
      message: event != null
          ? 'Did not receive expected $event event.'
          : 'Did not receive response to request "$id".',
    ).whenComplete(() => sub.cancel());
  }

  Future<T> _timeoutWithMessages<T>(
    Future<T> Function() f, {
    Duration? timeout,
    String? message,
  }) {
    // Capture output to a buffer so if we don't get the response we want we can show
    // the output that did arrive in the timeout error.
    final StringBuffer messages = StringBuffer();
    final DateTime start = DateTime.now();
    void logMessage(String m) {
      final int ms = DateTime.now().difference(start).inMilliseconds;
      messages.writeln('[+ ${ms.toString().padLeft(5)}] $m');
    }

    final StreamSubscription<String> sub =
        _allMessages.stream.listen(logMessage);

    return f().timeout(
      timeout ?? _defaultTimeout,
      onTimeout: () {
        logMessage('<timed out>');
        throw '$message';
      },
    ).catchError((dynamic error) {
      throw '$error\nReceived:\n${messages.toString()}';
    }).whenComplete(() => sub.cancel());
  }

  Map<String, dynamic>? _parseFlutterResponse(String line) {
    if (line.startsWith('[') && line.endsWith(']')) {
      try {
        final Map<String, dynamic>? resp = json.decode(line)[0];
        return resp;
      } catch (e) {
        // Not valid JSON, so likely some other output that was surrounded by [brackets]
        return null;
      }
    }
    return null;
  }

  String _debugPrint(String msg) {
    const int maxLength = 500;
    final String truncatedMsg =
        msg.length > maxLength ? msg.substring(0, maxLength) + '...' : msg;
    _allMessages.add(truncatedMsg);
    if (_printDebugOutputToStdOut) {
      print('$truncatedMsg');
    }
    return msg;
  }
}

Stream<String> transformToLines(Stream<List<int>> byteStream) {
  return byteStream
      .transform<String>(utf8.decoder)
      .transform<String>(const LineSplitter());
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
