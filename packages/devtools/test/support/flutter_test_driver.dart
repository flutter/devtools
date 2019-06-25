// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devtools/src/vm_service_wrapper.dart';
import 'package:pedantic/pedantic.dart';
import 'package:vm_service_lib/utils.dart';
import 'package:vm_service_lib/vm_service_lib.dart';
import 'package:vm_service_lib/vm_service_lib_io.dart';

/// This class was copied from
/// flutter/packages/flutter_tools/test/integration/test_driver.dart. Its
/// supporting classes were also copied from flutter/packages/flutter_tools.
/// Those files are marked as such and live in the parent directory of this file
/// (flutter_tools/).

// Set this to true for debugging to get JSON written to stdout.
const bool _printDebugOutputToStdOut = false;
const Duration defaultTimeout = Duration(seconds: 40);
const Duration appStartTimeout = Duration(seconds: 120);
const Duration quitTimeout = Duration(seconds: 10);

abstract class FlutterTestDriver {
  FlutterTestDriver(this._projectFolder, {String logPrefix})
      : _logPrefix = logPrefix != null ? '$logPrefix: ' : '';

  final Directory _projectFolder;
  final String _logPrefix;
  Process _proc;
  int _procPid;
  final StreamController<String> _stdout = StreamController<String>.broadcast();
  final StreamController<String> _stderr = StreamController<String>.broadcast();
  final StreamController<String> _allMessages =
      StreamController<String>.broadcast();
  final StringBuffer _errorBuffer = StringBuffer();
  String _lastResponse;
  Uri _vmServiceWsUri;
  bool _hasExited = false;

  VmServiceWrapper vmService;

  String get lastErrorInfo => _errorBuffer.toString();

  Stream<String> get stdout => _stdout.stream;

  Uri get vmServiceUri => _vmServiceWsUri;

  bool get hasExited => _hasExited;

  String _debugPrint(String msg) {
    const int maxLength = 500;
    final String truncatedMsg =
        msg.length > maxLength ? msg.substring(0, maxLength) + '...' : msg;
    _allMessages.add(truncatedMsg);
    if (_printDebugOutputToStdOut) {
      print('$_logPrefix$truncatedMsg');
    }
    return msg;
  }

  Future<void> _setupProcess(
    List<String> args, {
    FlutterRunConfiguration runConfig = const FlutterRunConfiguration(),
    File pidFile,
  }) async {
    if (runConfig.withDebugger) {
      args.add('--start-paused');
    }
    if (pidFile != null) {
      args.addAll(<String>['--pid-file', pidFile.path]);
    }
    _debugPrint('Spawning flutter $args in ${_projectFolder.path}');

    _proc = await Process.start(
        Platform.isWindows ? 'flutter.bat' : 'flutter', args,
        workingDirectory: _projectFolder.path,
        environment: <String, String>{
          'FLUTTER_TEST': 'true',
          'DART_VM_OPTIONS': '',
        });
    // This class doesn't use the result of the future. It's made available
    // via a getter for external uses.
    unawaited(_proc.exitCode.then((int code) {
      _debugPrint('Process exited ($code)');
      _hasExited = true;
    }));
    _transformToLines(_proc.stdout).listen((String line) => _stdout.add(line));
    _transformToLines(_proc.stderr).listen((String line) => _stderr.add(line));

    // Capture stderr to a buffer so we can show it all if any requests fail.
    _stderr.stream.listen(_errorBuffer.writeln);

    // This is just debug printing to aid running/debugging tests locally.
    _stdout.stream.listen(_debugPrint);
    _stderr.stream.listen(_debugPrint);
  }

  Future<int> _killGracefully() async {
    if (_procPid == null) {
      return -1;
    }
    _debugPrint('Sending SIGTERM to $_procPid..');
    Process.killPid(_procPid);
    return _proc.exitCode.timeout(quitTimeout, onTimeout: _killForcefully);
  }

  Future<int> _killForcefully() {
    _debugPrint('Sending SIGKILL to $_procPid..');
    Process.killPid(_procPid, ProcessSignal.sigkill);
    return _proc.exitCode;
  }

  String _flutterIsolateId;

  Future<String> getFlutterIsolateId() async {
    // Currently these tests only have a single isolate. If this
    // ceases to be the case, this code will need changing.
    if (_flutterIsolateId == null) {
      final VM vm = await vmService.getVM();
      _flutterIsolateId = vm.isolates.first.id;
    }
    return _flutterIsolateId;
  }

  Future<Isolate> _getFlutterIsolate() async {
    final Isolate isolate =
        await vmService.getIsolate(await getFlutterIsolateId());
    return isolate;
  }

  Future<Isolate> waitForPause() async {
    _debugPrint('Waiting for isolate to pause');
    final String flutterIsolate = await getFlutterIsolateId();

    Future<Isolate> waitForPause() async {
      final Completer<Event> pauseEvent = Completer<Event>();

      // Start listening for pause events.
      final StreamSubscription<Event> pauseSub = vmService.onDebugEvent
          .where((Event event) =>
              event.isolate.id == flutterIsolate &&
              event.kind.startsWith('Pause'))
          .listen(pauseEvent.complete);

      // But also check if the isolate was already paused (only after we've set
      // up the sub) to avoid races. If it was paused, we don't need to wait
      // for the event.
      final Isolate isolate = await vmService.getIsolate(flutterIsolate);
      if (!isolate.pauseEvent.kind.startsWith('Pause')) {
        await pauseEvent.future;
      }

      // Cancel the sub on either of the above.
      await pauseSub.cancel();

      return _getFlutterIsolate();
    }

    return _timeoutWithMessages<Isolate>(waitForPause,
        message: 'Isolate did not pause');
  }

  Future<Isolate> _resume({String step, bool wait = true}) async {
    _debugPrint('Sending resume ($step)');
    await _timeoutWithMessages<dynamic>(
        () async => vmService.resume(await getFlutterIsolateId(), step: step),
        message: 'Isolate did not respond to resume ($step)');
    return wait ? waitForPause() : null;
  }

  Future<Map<String, dynamic>> _waitFor({
    String event,
    int id,
    Duration timeout,
    bool ignoreAppStopEvent = false,
  }) async {
    final Completer<Map<String, dynamic>> response =
        Completer<Map<String, dynamic>>();
    StreamSubscription<String> sub;
    sub = _stdout.stream.listen((String line) async {
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
            '${event != null ? '$event event' : 'response to request $id.'}.\n\n');
        if (json['params'] != null && json['params']['error'] != null) {
          error.write('${json['params']['error']}\n\n');
        }
        if (json['params'] != null && json['params']['trace'] != null) {
          error.write('${json['params']['trace']}\n\n');
        }
        response.completeError(error.toString());
      }
    });

    return _timeoutWithMessages<Map<String, dynamic>>(() => response.future,
            timeout: timeout,
            message: event != null
                ? 'Did not receive expected $event event.'
                : 'Did not receive response to request "$id".')
        .whenComplete(() => sub.cancel());
  }

  Future<T> _timeoutWithMessages<T>(Future<T> Function() f,
      {Duration timeout, String message}) {
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

    return f().timeout(timeout ?? defaultTimeout, onTimeout: () {
      logMessage('<timed out>');
      throw '$message';
    }).catchError((dynamic error) {
      throw '$error\nReceived:\n${messages.toString()}';
    }).whenComplete(() => sub.cancel());
  }

  Map<String, dynamic> _parseFlutterResponse(String line) {
    if (line.startsWith('[') && line.endsWith(']')) {
      try {
        final Map<String, dynamic> resp = json.decode(line)[0];
        _lastResponse = line;
        return resp;
      } catch (e) {
        // Not valid JSON, so likely some other output that was surrounded by [brackets]
        return null;
      }
    }
    return null;
  }
}

class FlutterRunTestDriver extends FlutterTestDriver {
  FlutterRunTestDriver(Directory _projectFolder, {String logPrefix})
      : super(_projectFolder, logPrefix: logPrefix);

  String _currentRunningAppId;

  Future<void> run({
    FlutterRunConfiguration runConfig = const FlutterRunConfiguration(),
    File pidFile,
  }) async {
    final args = <String>[
      'run',
      '--machine',
    ];
    if (runConfig.trackWidgetCreation) {
      args.add('--track-widget-creation');
    }
    args.addAll(['-d', 'flutter-tester']);
    await _setupProcess(
      args,
      runConfig: runConfig,
      pidFile: pidFile,
    );
  }

  Future<void> attach(
    int port, {
    FlutterRunConfiguration runConfig = const FlutterRunConfiguration(),
    File pidFile,
  }) async {
    await _setupProcess(
      <String>[
        'attach',
        '--machine',
        '-d',
        'flutter-tester',
        '--debug-port',
        '$port',
      ],
      runConfig: runConfig,
      pidFile: pidFile,
    );
  }

  @override
  Future<void> _setupProcess(
    List<String> args, {
    FlutterRunConfiguration runConfig = const FlutterRunConfiguration(),
    File pidFile,
  }) async {
    await super._setupProcess(
      args,
      runConfig: runConfig,
      pidFile: pidFile,
    );

    // Stash the PID so that we can terminate the VM more reliably than using
    // _proc.kill() (because _proc is a shell, because `flutter` is a shell
    // script).
    final Map<String, dynamic> connected =
        await _waitFor(event: 'daemon.connected');
    _procPid = connected['params']['pid'];

    // Set this up now, but we don't wait it yet. We want to make sure we don't
    // miss it while waiting for debugPort below.
    final Future<Map<String, dynamic>> started =
        _waitFor(event: 'app.started', timeout: appStartTimeout);

    if (runConfig.withDebugger) {
      final Map<String, dynamic> debugPort =
          await _waitFor(event: 'app.debugPort', timeout: appStartTimeout);
      final String wsUriString = debugPort['params']['wsUri'];
      _vmServiceWsUri = Uri.parse(wsUriString);

      // Map to WS URI.
      _vmServiceWsUri =
          convertToWebSocketUrl(serviceProtocolUrl: _vmServiceWsUri);

      vmService = VmServiceWrapper(
        await vmServiceConnectUri(_vmServiceWsUri.toString()),
        trackFutures: true,
      );
      vmService.onSend.listen((String s) => _debugPrint('==> $s'));
      vmService.onReceive.listen((String s) => _debugPrint('<== $s'));
      await Future.wait(<Future<Success>>[
        vmService.streamListen(EventStreams.kIsolate),
        vmService.streamListen(EventStreams.kDebug),
      ]);

      // On hot restarts, the isolate ID we have for the Flutter thread will
      // exit so we need to invalidate our cached ID.
      vmService.onIsolateEvent.listen((Event event) {
        if (event.kind == EventKind.kIsolateExit &&
            event.isolate.id == _flutterIsolateId) {
          _flutterIsolateId = null;
        }
      });

      // Because we start paused, resume so the app is in a "running" state as
      // expected by tests. Tests will reload/restart as required if they need
      // to hit breakpoints, etc.
      await waitForPause();
      if (runConfig.pauseOnExceptions) {
        await vmService.setExceptionPauseMode(
            await getFlutterIsolateId(), ExceptionPauseMode.kUnhandled);
      }
      await _resume(wait: false);
    }

    // Now await the started event; if it had already happened the future will
    // have already completed.
    _currentRunningAppId = (await started)['params']['appId'];
  }

  Future<void> hotRestart({bool pause = false}) =>
      _restart(fullRestart: true, pause: pause);

  Future<void> hotReload() => _restart(fullRestart: false);

  Future<void> _restart({bool fullRestart = false, bool pause = false}) async {
    if (_currentRunningAppId == null) {
      throw Exception('App has not started yet');
    }

    final dynamic hotReloadResp = await _sendRequest(
      'app.restart',
      <String, dynamic>{
        'appId': _currentRunningAppId,
        'fullRestart': fullRestart,
        'pause': pause
      },
    );

    if (hotReloadResp == null || hotReloadResp['code'] != 0) {
      _throwErrorResponse(
          'Hot ${fullRestart ? 'restart' : 'reload'} request failed');
    }
  }

  Future<int> detach() async {
    if (vmService != null) {
      _debugPrint('Closing VM service');
      vmService.dispose();
    }
    if (_currentRunningAppId != null) {
      _debugPrint('Detaching from app');
      await Future.any<void>(<Future<void>>[
        _proc.exitCode,
        _sendRequest(
          'app.detach',
          <String, dynamic>{'appId': _currentRunningAppId},
        ),
      ]).timeout(
        quitTimeout,
        onTimeout: () {
          _debugPrint('app.detach did not return within $quitTimeout');
        },
      );
      _currentRunningAppId = null;
    }
    _debugPrint('Waiting for process to end');
    return _proc.exitCode.timeout(quitTimeout, onTimeout: _killGracefully);
  }

  Future<int> stop() async {
    if (vmService != null) {
      _debugPrint('Closing VM service');
      vmService.dispose();
    }
    if (_currentRunningAppId != null) {
      _debugPrint('Stopping app');
      await Future.any<void>(<Future<void>>[
        _proc.exitCode,
        _sendRequest(
          'app.stop',
          <String, dynamic>{'appId': _currentRunningAppId},
        ),
      ]).timeout(
        quitTimeout,
        onTimeout: () {
          _debugPrint('app.stop did not return within $quitTimeout');
        },
      );
      _currentRunningAppId = null;
    }
    if (_proc != null) {
      _debugPrint('Waiting for process to end');
      return _proc.exitCode.timeout(quitTimeout, onTimeout: _killGracefully);
    }
    return 0;
  }

  int id = 1;

  Future<dynamic> _sendRequest(String method, dynamic params) async {
    final int requestId = id++;
    final Map<String, dynamic> request = <String, dynamic>{
      'id': requestId,
      'method': method,
      'params': params
    };
    final String jsonEncoded = json.encode(<Map<String, dynamic>>[request]);
    _debugPrint(jsonEncoded);

    // Set up the response future before we send the request to avoid any
    // races. If the method we're calling is app.stop then we tell waitFor not
    // to throw if it sees an app.stop event before the response to this request.
    final Future<Map<String, dynamic>> responseFuture = _waitFor(
      id: requestId,
      ignoreAppStopEvent: method == 'app.stop',
    );
    _proc.stdin.writeln(jsonEncoded);
    final Map<String, dynamic> response = await responseFuture;

    if (response['error'] != null || response['result'] == null) {
      _throwErrorResponse('Unexpected error response');
    }

    return response['result'];
  }

  void _throwErrorResponse(String msg) {
    throw '$msg\n\n$_lastResponse\n\n${_errorBuffer.toString()}'.trim();
  }
}

Stream<String> _transformToLines(Stream<List<int>> byteStream) {
  return byteStream
      .transform<String>(utf8.decoder)
      .transform<String>(const LineSplitter());
}

class FlutterRunConfiguration {
  const FlutterRunConfiguration({
    this.withDebugger = false,
    this.pauseOnExceptions = false,
    this.trackWidgetCreation = true,
  });

  final bool withDebugger;
  final bool pauseOnExceptions;
  final bool trackWidgetCreation;
}
