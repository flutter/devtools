// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:test/test.dart';

import 'app.dart';
import 'debugger.dart';
import 'integration.dart';
import 'logging.dart';

void main() {
  group('integration', () {
    setUpAll(() async {
      webdevFixture = await WebdevFixture.create(verbose: true);
      browserManager = await BrowserManager.create();
    });

    tearDownAll(() async {
      await browserManager?.teardown();
      await webdevFixture?.teardown();
    });

    group('app', appTests);
    group('logging', loggingTests);
    group('debugging', debuggingTests);
  }, timeout: const Timeout.factor(2));
}
