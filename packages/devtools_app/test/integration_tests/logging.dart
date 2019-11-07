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
    await tools.switchPage('logging');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'logging');

    // Cause app to log.
    final LoggingManager logs = LoggingManager(tools);
    await logs.clearLogs();
    expect(await logs.logCount(), 0);
    await appFixture.invoke('controller.emitLog()');

    // Verify the log data shows up in the UI.
    await waitFor(() async => await logs.logCount() > 0);
    expect(await logs.logCount(), greaterThan(0));
  });

  test('filter log data', () async {
    final DevtoolsManager tools =
        DevtoolsManager(tabInstance, webdevFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('logging');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'logging');

    // Cause app to log.
    final LoggingManager logs = LoggingManager(tools);
    await logs.clearLogs();

    await appFixture.invoke('controller.emitLogForString("string1")');
    await appFixture.invoke('controller.emitLogForString("string1")');
    await appFixture.invoke('controller.emitLogForString("string1")');
    await appFixture.invoke('controller.emitLogForString("string2")');
    await appFixture.invoke('controller.emitLogForString("string2")');
    await waitFor(() async => await logs.logCount() > 0);
    final countAll = await logs.logCount();
    expect(countAll, equals(5));

    await logs.filterLogs('string1');
    final countStr1 = await logs.logCount();
    expect(countStr1, equals(3));

    await logs.filterLogs('string2');
    final countStr2 = await logs.logCount();
    expect(countStr2, equals(2));

    await logs.filterLogs('string');
    final countStr = await logs.logCount();
    expect(countStr, equals(5));

    await logs.filterLogs('string3');
    final countStr3 = await logs.logCount();
    expect(countStr3, equals(0));

    await logs.filterLogs('');
    final countStrEmpty = await logs.logCount();
    expect(countStrEmpty, equals(5));
  });

  test('log screen postpones write when offscreen', () async {
    final DevtoolsManager tools =
        DevtoolsManager(tabInstance, webdevFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('logging');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'logging');

    final LoggingManager logs = LoggingManager(tools);

    // Verify that the log is empty.
    expect(await logs.logCount(), 0);

    // Switch to a different page.
    await tools.switchPage('performance');

    // Cause app to log.
    await appFixture.invoke('controller.emitLog()');

    // Verify that the log is empty.
    expect(await logs.logCount(), 0);

    // Switch to the logs page.
    await tools.switchPage('logging');

    // Verify the log data shows up in the UI.
    await waitFor(() async => await logs.logCount() > 0);
    expect(await logs.logCount(), greaterThan(0));
  });
}

class LoggingManager {
  LoggingManager(this.tools);

  final DevtoolsManager tools;

  Future<void> clearLogs() async {
    await tools.tabInstance.send('logging.clearLogs');
  }

  Future<void> filterLogs(String text) async {
    await tools.tabInstance.send('logging.filterLogs', text);
  }

  Future<int> logCount() async {
    final AppResponse response =
        await tools.tabInstance.send('logging.logCount');
    return response.result;
  }
}
