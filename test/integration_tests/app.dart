// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import '../support/cli_test_driver.dart';
import 'integration.dart';

void appTests() {
  CliAppFixture appFixture;
  BrowserTabInstance tabInstance;

  setUp(() async {
    appFixture = await CliAppFixture.create('test/fixtures/logging_app.dart');
    tabInstance = await browserManager.createNewTab();
  });

  tearDown(() async {
    await tabInstance?.close();
    await appFixture?.teardown();
  });

  test('can switch pages', () async {
    final DevtoolsManager tools =
        DevtoolsManager(tabInstance, webdevFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('logs');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'logs');
  });
}
