// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import '_io_utils.dart';
import '_utils.dart';

class ChromeDriver with IOMixin {
  late final Process _process;

  // TODO(kenz): add error messaging if the chromedriver executable is not
  // found. We can also consider using web installers directly in this script:
  // https://github.com/flutter/flutter/wiki/Running-Flutter-Driver-tests-with-Web#web-installers-repo.
  Future<void> start() async {
    try {
      debugLog('starting the chromedriver process');
      _process = await Process.start(
        'chromedriver',
        [
          '--port=4444',
        ],
      );
      listenToProcessOutput(_process, printTag: 'ChromeDriver');
    } catch (e) {
      // ignore: avoid-throw-in-catch-block, by design
      throw Exception('Error starting chromedriver: $e');
    }
  }

  Future<void> stop() async {
    await cancelAllStreamSubscriptions();
    debugLog('killing the chromedriver process');
    _process.kill();
  }
}
