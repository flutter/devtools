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
    server.kill();
    await appFixture?.teardown();
    await webdevFixture?.teardown();
  });

  test('registers service', () async {
    // Track services as they're registered.
    final registeredServices = <String>{};
    // TODO(dantup): Remove this loop and just use
    // appFixture.serviceConnection.onServiceEvent
    // directly once the VM Service makes it to stable.
    for (final serviceId in ['Service', '_Service']) {
      appFixture.serviceConnection
          .onEvent(serviceId)
          .where((e) => e.kind == EventKind.kServiceRegistered)
          .listen((e) => registeredServices.add(e.service));
      await appFixture.serviceConnection
          .streamListen(serviceId)
          .catchError((e, stack) {
        // TODO(dantup): Remove this empty catch when removing the loop, as it
        // will no longer be required. We currently need it because one of the
        // streams will fail.
      });
    }

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
  }, timeout: const Timeout.factor(10));
}
