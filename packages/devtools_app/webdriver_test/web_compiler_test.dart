// Copyright 2026 The Flutter Authors
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

  const serverStartupTimeout = Duration(minutes: 1);

  setUpAll(() async {
    // Start ChromeDriver.
    await ChromeDriver().start(debugLogging: true);

    // Start the DevTools server.
    devtoolsProcess = await startDevToolsServer();
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

  tearDownAll(() async {
    await driver.quit();
    devtoolsProcess.kill();
  });

  /// Reads the "flt-renderer" attribute on the body element.
  ///
  /// This can be used to determine whether the render is canvaskit or skwasm:
  /// https://github.com/flutter/devtools/pull/9406#pullrequestreview-3142210823
  Future<String?> readRendererAttribute() => retryAsync<String?>(
    () async {
      final body = await driver.findElement(const By.tagName('body'));
      return body.attributes['flt-renderer'];
    },
    condition: (result) => result != null,
    onRetry: () => Future.delayed(const Duration(milliseconds: 250)),
  );

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
        expect(await readRendererAttribute(), equals('skwasm'));

        // Open the DevTools URL with ?compiler=js.
        await driver.get(
          _addQueryParam(devToolsServerAddress, param: 'compiler', value: 'js'),
        );

        // Verify we are using the canvaskit renderer.
        expect(await readRendererAttribute(), equals('canvaskit'));
      },
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
