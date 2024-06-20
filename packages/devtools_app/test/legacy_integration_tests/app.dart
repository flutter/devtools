// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_test_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import 'integration.dart';

void appTests() {
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

  test('can switch pages', () async {
    final tools = DevtoolsManager(tabInstance, webBuildFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('logging');

    final currentPageId = await tools.currentPageId();
    expect(currentPageId, 'logging');
  });

  test('connect dialog displays', () async {
    // start with no port
    final baseAppUri = webBuildFixture.baseUri.resolve('index.html');
    final tools = DevtoolsManager(tabInstance, webBuildFixture.baseUri);
    await tools.start(
      appFixture,
      overrideUri: baseAppUri,
      waitForConnection: false,
    );

    final connectDialog = ConnectDialogManager(tools);

    // make sure the connect dialog displays
    await waitFor(() async => await connectDialog.isVisible());

    // have it connect to a port
    await connectDialog.connectTo(appFixture.serviceUri);

    // make sure the connect dialog becomes hidden
    await waitFor(() async => !(await connectDialog.isVisible()));
  });
}

class ConnectDialogManager {
  ConnectDialogManager(this.tools);

  final DevtoolsManager tools;

  Future<bool> isVisible() async {
    final response = await tools.tabInstance.send('connectDialog.isVisible');
    return response.result as bool;
  }

  Future connectTo(Uri uri) async {
    // We have to convert to String here as this goes over JSON.
    await tools.tabInstance.send('connectDialog.connectTo', uri.toString());
  }
}
