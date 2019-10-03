// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:io';

import 'package:test/test.dart';

import 'app.dart';
import 'debugger.dart';
import 'integration.dart';
import 'logging.dart';

void main() {
  group('integration', () {
    setUpAll(() async {
      final bool testInReleaseMode =
          Platform.environment['WEBDEV_RELEASE'] == 'true';

      webdevFixture =
          await WebdevFixture.serve(release: testInReleaseMode, verbose: true);
      print('Fixture: ${webdevFixture.process}, ${webdevFixture.url}');
      browserManager = await BrowserManager.create();
      print('Browser manager: ${browserManager.chromeProcess}');
    });

    tearDownAll(() async {
      await browserManager?.teardown();
      await webdevFixture?.teardown();
    });

    group('app', appTests);
    group('logging', loggingTests);
    group('debugging', debuggingTests);
  }, timeout: const Timeout.factor(4));
}
