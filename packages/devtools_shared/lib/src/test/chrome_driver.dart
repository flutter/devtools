// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: avoid_print

import 'dart:io';

import 'io_utils.dart';

class ChromeDriver with IOMixin {
  static const port = 4444;

  Process? _process;

  // TODO(kenz): add error messaging if the chromedriver executable is not
  // found. We can also consider using web installers directly in this script:
  // https://github.com/flutter/flutter/blob/master/docs/contributing/testing/Running-Flutter-Driver-tests-with-Web.md#web-installers-repo.
  Future<void> start({bool debugLogging = false}) async {
    try {
      const chromedriverExe = 'chromedriver';
      const chromedriverArgs = ['--port=$port'];
      if (debugLogging) {
        print('${DateTime.now()}: starting the chromedriver process');
        print(
          '${DateTime.now()}: > $chromedriverExe '
          '${chromedriverArgs.join(' ')}',
        );
      }
      final process = _process = await Process.start(
        chromedriverExe,
        chromedriverArgs,
      );
      listenToProcessOutput(process, printTag: 'ChromeDriver');
      await _waitForPortOpen(port);
    } catch (e) {
      // ignore: avoid-throw-in-catch-block, by design
      throw Exception('Error starting chromedriver: $e');
    }
  }

  Future<void> stop({bool debugLogging = false}) async {
    final process = _process;
    _process = null;

    if (process == null) return;

    await cancelAllStreamSubscriptions();

    if (debugLogging) {
      print('${DateTime.now()}: killing the chromedriver process');
    }
    await killGracefully(process, debugLogging: debugLogging);
  }

  Future<void> _waitForPortOpen(
    int port, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      try {
        final socket = await Socket.connect('127.0.0.1', port);
        socket.destroy();
        stopwatch.stop();
        return;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    stopwatch.stop();
    throw Exception(
      'ChromeDriver failed to start on port $port within ${timeout.inSeconds} seconds.',
    );
  }
}
