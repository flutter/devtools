// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import '../support/cli_test_driver.dart';
import 'integration.dart';

void loggingTests() {
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

  test('displays log data', () async {
    final DevtoolsManager tools =
        DevtoolsManager(tabInstance, webdevFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('logs');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'logs');

    // Cause app to log.
    final LoggingManager logs = LoggingManager(tools);
    await logs.clearLogs();
    expect(await logs.logCount(), 0);
    await appFixture.invoke('controller.emitLog()');

    // Verify the log data shows up in the UI.
    await waitFor(() async => await logs.logCount() > 0);
    expect(await logs.logCount(), greaterThan(0));
  });

  test('log screen postpones write when offscreen', () async {
    final DevtoolsManager tools =
        DevtoolsManager(tabInstance, webdevFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('logs');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'logs');

    final LoggingManager logs = LoggingManager(tools);

    // Verify that the log is empty.
    expect(await logs.logCount(), 0);

    // Switch to a different page.
    await tools.switchPage('timeline');

    // Cause app to log.
    await appFixture.invoke('controller.emitLog()');

    // Verify that the log is empty.
    expect(await logs.logCount(), 0);

    // Switch to the logs page.
    await tools.switchPage('logs');

    // Verify the log data shows up in the UI.
    await waitFor(() async => await logs.logCount() > 0);
    expect(await logs.logCount(), greaterThan(0));
  });
}

class LoggingManager {
  LoggingManager(this.tools);

  final DevtoolsManager tools;

  Future<void> clearLogs() async {
    await tools.tabInstance.send('logs.clearLogs');
  }

  Future<int> logCount() async {
    final AppResponse response = await tools.tabInstance.send('logs.logCount');
    return response.result;
  }
}
