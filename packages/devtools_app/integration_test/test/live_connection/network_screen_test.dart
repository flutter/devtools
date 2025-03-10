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
import 'package:http/http.dart' as http;
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

  testWidgets('nnn', (tester) async {
    await pumpAndConnectDevTools(tester, testApp);
    await _prepareNetworkScreen(tester);

    final helper = _NetworkScreenHelper(tester, testApp.controlPort!);

    // Instruct the app to make a GET request via the dart:io HttpClient.
    await helper.triggerRequest('get/');
    _expectInRequestTable('GET');
    await helper.clear();

    // Instruct the app to make a POST request via the dart:io HttpClient.
    await helper.triggerRequest('post/');
    _expectInRequestTable('POST');
    await helper.clear();

    // Instruct the app to make a PUT request via the dart:io HttpClient.
    await helper.triggerRequest('put/');
    _expectInRequestTable('PUT');
    await helper.clear();

    // Instruct the app to make a DELETE request via the dart:io HttpClient.
    await helper.triggerRequest('delete/');
    _expectInRequestTable('DELETE');
    await helper.clear();

    // Instruct the app to make a GET request via Dio.
    await helper.triggerRequest('dio/get/');
    _expectInRequestTable('GET');
    await helper.clear();

    // Instruct the app to make a POST request via Dio.
    await helper.triggerRequest('dio/post/');
    _expectInRequestTable('POST');
  });
}

final class _NetworkScreenHelper {
  _NetworkScreenHelper(this._tester, this._controlPort);

  final WidgetTester _tester;

  final int _controlPort;

  Future<void> clear() async {
    // Press the 'Clear' button between tests.
    await _tester.tap(find.text('Clear'));
    await _tester.pump(safePumpDuration);
  }

  Future<void> triggerRequest(String path) async {
    await http.get(Uri.parse('http://localhost:$_controlPort/$path'));
    await Future.delayed(const Duration(milliseconds: 200));
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
