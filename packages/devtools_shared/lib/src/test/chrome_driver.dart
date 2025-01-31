// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: avoid_print

import 'dart:io';

import 'io_utils.dart';

class ChromeDriver with IOMixin {
  Process? _process;

  // TODO(kenz): add error messaging if the chromedriver executable is not
  // found. We can also consider using web installers directly in this script:
  // https://github.com/flutter/flutter/blob/master/docs/contributing/testing/Running-Flutter-Driver-tests-with-Web.md#web-installers-repo.
  Future<void> start({bool debugLogging = false}) async {
    try {
      const chromedriverExe = 'chromedriver';
      const chromedriverArgs = ['--port=4444'];
      if (debugLogging) {
        print('starting the chromedriver process');
        print('> $chromedriverExe ${chromedriverArgs.join(' ')}');
      }
      final process = _process = await Process.start(
        chromedriverExe,
        chromedriverArgs,
      );
      listenToProcessOutput(process, printTag: 'ChromeDriver');
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
      print('killing the chromedriver process');
    }
    await killGracefully(process, debugLogging: debugLogging);
  }
}
