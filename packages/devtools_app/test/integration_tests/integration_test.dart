// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:io';

import 'package:devtools_testing/support/file_utils.dart';
import 'package:test/test.dart';

import 'app.dart';
import 'debugger.dart';
import 'integration.dart';
import 'logging.dart';

void main() {
  group('integration', () {
    // TODO(#1965): fix and re-enable integration tests.
    // ignore: dead_code
    if (false) {
      setUpAll(() async {
        compensateForFlutterTestDirectoryBug();
        final bool testInReleaseMode =
            Platform.environment['WEBDEV_RELEASE'] == 'true';

        webBuildFixture = await WebBuildFixture.serve(
            release: testInReleaseMode, verbose: true);
        browserManager = await BrowserManager.create();
      });

      tearDownAll(() async {
        await browserManager?.teardown();
        await webBuildFixture?.teardown();
      });

      group('app', appTests, skip: true);
      group('logging', loggingTests, skip: true);
      // Temporarily skip tests. See https://github.com/flutter/devtools/issues/1343.
      group('debugging', debuggingTests, skip: true);
    }
  }, timeout: const Timeout.factor(8));
}
