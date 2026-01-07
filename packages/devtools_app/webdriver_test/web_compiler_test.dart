// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:io';

import 'package:devtools_shared/devtools_test_utils.dart';
import 'package:devtools_test/helpers.dart';
import 'package:devtools_test/integration_test.dart';
import 'package:test/test.dart';
import 'package:webdriver/async_io.dart';

import '../integration_test/test_infra/run/run_test.dart';

void main() {
  late Process devtoolsProcess;
  late WebDriver driver;
  late String devToolsServerAddress;

  const serverStartupTimeout = Duration(minutes: 3);

  setUp(() async {
    // Start ChromeDriver.
    await ChromeDriver().start(debugLogging: true);

    // Start the DevTools server.
    devtoolsProcess = await startDevToolsServer(useLocalServer: true);
    devToolsServerAddress = await listenForDevToolsAddress(
      devtoolsProcess,
      timeout: serverStartupTimeout,
    );

    // Create a WebDriver instance.
    driver = await createDriver(
      uri: Uri.parse('http://127.0.0.1:${ChromeDriver.port}'),
      desired: {
        ...Capabilities.chrome,
        Capabilities.chromeOptions: {
          'args': ['--headless'],
        },
      },
    );
  });

  tearDown(() async {
    await driver.quit();
    devtoolsProcess.kill();
  });

  Future<String?> getRendererAttribute() => retryUntilNotNull(() async {
    final body = await driver.findElement(const By.tagName('body'));
    return body.attributes['flt-renderer'];
  });

  group('compilation', () {
    test(
      'compiler query param determines skwasm/canvaskit renderer',
      timeout: longTimeout,
      () async {
        // Open the DevTools URL with ?compiler=wasm.
        await driver.get(
          _addQueryParam(
            devToolsServerAddress,
            param: 'compiler',
            value: 'wasm',
          ),
        );
        // Verify we are using the skwasm renderer.
        expect(await getRendererAttribute(), equals('skwasm'));

        // Open the DevTools URL with ?compiler=js.
        await driver.get(
          _addQueryParam(devToolsServerAddress, param: 'compiler', value: 'js'),
        );
        // Verify we are using the canvaskit renderer.
        expect(await getRendererAttribute(), equals('canvaskit'));
      },
      retry: 1,
    );
  });
}

String _addQueryParam(
  String url, {
  required String param,
  required String value,
}) {
  final uri = Uri.parse(url);
  final newQueryParameters = Map<String, dynamic>.of(uri.queryParameters);
  newQueryParameters[param] = value;
  return uri.replace(queryParameters: newQueryParameters).toString();
}
