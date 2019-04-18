// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart';

// TODO(kenzie): move this code to dart-lang/browser_launcher. This code was
// copied from https://github.com/dart-lang/webdev/blob/master/webdev/lib/src/serve/chrome.dart

const _chromeEnvironment = 'CHROME_EXECUTABLE';
const _linuxExecutable = 'google-chrome';
const _macOSExecutable =
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const _windowsExecutable = r'Google\Chrome\Application\chrome.exe';

String get _executable {
  if (Platform.environment.containsKey(_chromeEnvironment)) {
    return Platform.environment[_chromeEnvironment];
  }
  if (Platform.isLinux) return _linuxExecutable;
  if (Platform.isMacOS) return _macOSExecutable;
  if (Platform.isWindows) return _windowsExecutable;
  throw StateError('Unexpected platform type.');
}

var _currentCompleter = Completer<Chrome>();

/// A class for managing an instance of Chrome.
class Chrome {
  Chrome._(
    this.chromeConnection, {
    this.debugPort,
    Process process,
    Directory dataDir,
  })  : _process = process,
        _dataDir = dataDir;

  final int debugPort;
  final Process _process;
  final Directory _dataDir;
  final ChromeConnection chromeConnection;

  Future<void> close() async {
    if (_currentCompleter.isCompleted) _currentCompleter = Completer<Chrome>();
    chromeConnection.close();
    _process?.kill();
    await _process?.exitCode;
    await _dataDir?.delete(recursive: true);
  }

  static Future<Chrome> get connectedInstance => _currentCompleter.future;

  /// Starts Chrome with the given arguments and a specific port.
  ///
  /// Each url in [urls] will be loaded in a separate tab.
  static Future<void> startWithPort(
    List<String> urls, {
    List<String> args,
    int port,
  }) async {
    port = port == null || port == 0 ? await findUnusedPort() : port;
    return start(urls, args: args, port: port);
  }

  /// Starts Chrome with the given arguments.
  ///
  /// Each url in [urls] will be loaded in a separate tab.
  static Future<void> start(
    List<String> urls, {
    List<String> args,
    int port,
  }) async {
    args ??= [];
    args.addAll(urls);

    await Process.start(_executable, args);
  }
}

/// Returns a port that is probably, but not definitely, not in use.
///
/// This has a built-in race condition: another process may bind this port at
/// any time after this call has returned.
Future<int> findUnusedPort() async {
  int port;
  ServerSocket socket;
  try {
    socket =
        await ServerSocket.bind(InternetAddress.loopbackIPv6, 0, v6Only: true);
  } on SocketException {
    socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  }
  port = socket.port;
  await socket.close();
  return port;
}
