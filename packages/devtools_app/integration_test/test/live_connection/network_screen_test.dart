// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// Do not delete these arguments. They are parsed by test runner.
// test-argument:appPath="test/test_infra/fixtures/networking_app/bin/main.dart"

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/table/table.dart' show DevToolsTable;
import 'package:devtools_test/helpers.dart';
import 'package:devtools_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// To run:
// dart run integration_test/run_tests.dart --target=integration_test/test/live_connection/network_screen_test.dart --test-app-device=cli

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp testApp;

  setUpAll(() {
    testApp = TestApp.fromEnvironment();
    expect(testApp.vmServiceUri, isNotNull);
  });

  tearDown(() async {
    await resetHistory();
  });

  testWidgets('network screen test', timeout: mediumTimeout, (tester) async {
    await pumpAndConnectDevTools(tester, testApp);
    await _prepareNetworkScreen(tester);

    final helper = _NetworkScreenHelper(tester);

    // Instruct the app to make a GET request via the dart:io HttpClient.
    await helper.triggerRequest('get');
    _expectInRequestTable('GET');
    await helper.clear();

    // Instruct the app to make a POST request via the dart:io HttpClient.
    await helper.triggerRequest('post');
    _expectInRequestTable('POST');
    await helper.clear();

    // Instruct the app to make a PUT request via the dart:io HttpClient.
    await helper.triggerRequest('put');
    _expectInRequestTable('PUT');
    await helper.clear();

    // Instruct the app to make a DELETE request via the dart:io HttpClient.
    await helper.triggerRequest('delete');
    _expectInRequestTable('DELETE');
    await helper.clear();

    // Instruct the app to make a GET request via the 'http' package.
    await helper.triggerRequest('packageHttpGet');
    _expectInRequestTable('GET');
    await helper.clear();

    // Instruct the app to make a POST request via the 'http' package.
    await helper.triggerRequest('packageHttpPost');
    _expectInRequestTable('POST');
    await helper.clear();

    // Instruct the app to make a GET request via Dio.
    await helper.triggerRequest('dioGet');
    _expectInRequestTable('GET');
    await helper.clear();

    // Instruct the app to make a POST request via Dio.
    await helper.triggerRequest('dioPost');
    _expectInRequestTable('POST');

    // Perform a Hot Reload, then make more requests.
    await serviceConnection.serviceManager.performHotReload();

    // Instruct the app to make a GET request via the 'http' package.
    await helper.triggerRequest('packageHttpGet');
    _expectInRequestTable('GET');
    await helper.clear();

    // Perform a Hot Restart, then make more requests.
    await serviceConnection.serviceManager.performHotRestart();

    // Instruct the app to make a GET request via the 'http' package.
    await helper.triggerRequest('packageHttpGet');
    _expectInRequestTable('GET');
    await helper.clear();

    await helper.triggerExit();
  });
}

final class _NetworkScreenHelper {
  _NetworkScreenHelper(this._tester);

  final WidgetTester _tester;

  Future<void> clear() async {
    // Press the 'Clear' button between tests.
    await _tester.tap(find.text('Clear'));
    await _tester.pump(safePumpDuration);
    expect(
      screenControllers.lookup<NetworkController>().requests.value,
      isEmpty,
    );
  }

  Future<void> triggerExit() async {
    final response = await serviceConnection.serviceManager
        .callServiceExtensionOnMainIsolate('ext.networking_app.exit');
    logStatus(response.toString());

    await Future.delayed(const Duration(milliseconds: 200));
    await _tester.pump(safePumpDuration);
  }

  Future<void> triggerRequest(
    String requestType, {
    bool hasBody = false,
  }) async {
    final response = await serviceConnection.serviceManager
        .callServiceExtensionOnMainIsolate(
          'ext.networking_app.makeRequest',
          args: {'requestType': requestType, 'hasBody': hasBody},
        );
    logStatus(
      'Sent a $requestType request, received response: ${response.json}',
    );

    await _tester.pump(safePumpDuration);
  }
}

void _expectInRequestTable(String text) {
  expect(
    find.descendant(
      of: find.byType(DevToolsTable<NetworkRequest>),
      matching: find.text(text),
    ),
    findsOneWidget,
  );
}

/// Prepares the UI of the network screen for an integration test.
Future<void> _prepareNetworkScreen(WidgetTester tester) async {
  await switchToScreen(
    tester,
    tabIcon: ScreenMetaData.network.icon,
    tabIconAsset: ScreenMetaData.network.iconAsset,
    screenId: ScreenMetaData.network.id,
  );
}
