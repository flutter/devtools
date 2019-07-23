// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:io';

import 'package:test/test.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import '../support/cli_test_driver.dart';
import '../support/devtools_server_driver.dart';
import 'integration.dart';

void main() {
  CliAppFixture appFixture;
  DevToolsServerDriver server;

  setUp(() async {
    // Build the app, as the server can't start without the build output.
    await WebdevFixture.build(verbose: true);

    // The packages folder needs to be renamed to `pack` for the server to work.
    if (await Directory('build/pack').exists()) {
      await Directory('build/pack').delete(recursive: true);
    }
    await Directory('build/packages').rename('build/pack');

    // Start the command-line server.
    server = await DevToolsServerDriver.create();

    // Start a test app we can use to connect to.
    appFixture = await CliAppFixture.create('test/fixtures/empty_app.dart');
  });

  tearDown(() async {
    server?.kill();
    await appFixture?.teardown();
  });

  test('registers service', () async {
    // Track services as they're registered.
    final registeredServices = <String>{};

    // TODO(dantup): When the stable versions of Dart + Flutter are >= v3.22
    // of the VM Service (July 2019), the _Service option here can be removed.
    final serviceName = await appFixture.serviceConnection.serviceStreamName;

    appFixture.serviceConnection
        .onEvent(serviceName)
        .where((e) => e.kind == EventKind.kServiceRegistered)
        .listen((e) => registeredServices.add(e.service));

    await appFixture.serviceConnection.streamListen(serviceName);

    server.stderr.listen((text) => throw 'STDERR: $text');

    server.write({
      'id': '10',
      'method': 'vm.register',
      'params': {'uri': appFixture.serviceUri.toString()}
    });

    // Expect to get a successful response from the server.
    final serverResponse =
        await server.output.firstWhere((e) => e['id'] == '10');
    expect(serverResponse['result']['success'], isTrue);

    // Expect the VM service to see the launchDevTools service registered.
    expect(registeredServices, contains('launchDevTools'));
    // Skipped on Windows due to webdev failing to start immediately after
    // other tests fail.
    // https://github.com/flutter/devtools/pull/802#issuecomment-512722437
  }, timeout: const Timeout.factor(10), skip: Platform.isWindows);
}
