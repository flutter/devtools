// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_test_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import 'integration.dart';

void loggingTests() {
  late CliAppFixture appFixture;
  late BrowserTabInstance tabInstance;

  setUp(() async {
    appFixture =
        await CliAppFixture.create('test/test_infra/fixtures/logging_app.dart');
    tabInstance = await browserManager.createNewTab();
  });

  tearDown(() async {
    await tabInstance.close();
    await appFixture.teardown();
  });

  test('displays log data', () async {
    final tools = DevtoolsManager(tabInstance, webBuildFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('logging');

    final currentPageId = await tools.currentPageId();
    expect(currentPageId, 'logging');

    // Cause app to log.
    final logs = LoggingManager(tools);
    await logs.clearLogs();
    expect(await logs.logCount(), 0);
    await appFixture.invoke('controller.emitLog()');

    // Verify the log data shows up in the UI.
    await waitFor(() async => (await logs.logCount()) > 0);
    expect(await logs.logCount(), greaterThan(0));
  });

  test('log screen postpones write when offscreen', () async {
    final tools = DevtoolsManager(tabInstance, webBuildFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('logging');

    final currentPageId = await tools.currentPageId();
    expect(currentPageId, 'logging');

    final logs = LoggingManager(tools);

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
    await waitFor(() async => (await logs.logCount()) > 0);
    expect(await logs.logCount(), greaterThan(0));
  });
}

class LoggingManager {
  LoggingManager(this.tools);

  final DevtoolsManager tools;

  Future<void> clearLogs() async {
    await tools.tabInstance.send('logging.clearLogs');
  }

  Future<int> logCount() async {
    final response = await tools.tabInstance.send('logging.logCount');
    return response.result as int;
  }
}
