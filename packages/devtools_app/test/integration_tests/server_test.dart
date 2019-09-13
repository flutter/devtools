// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:io';

import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart';

import '../support/cli_test_driver.dart';
import '../support/devtools_server_driver.dart';
import 'integration.dart';

void main() {
  CliAppFixture appFixture;
  DevToolsServerDriver server;

  setUp(() async {
    final bool testInReleaseMode =
        Platform.environment['WEBDEV_RELEASE'] == 'true';

    // Build the app, as the server can't start without the build output.
    await WebdevFixture.build(release: testInReleaseMode, verbose: true);

    // The packages folder needs to be renamed to `pack` for the server to work.
    if (Directory('build/pack').existsSync()) {
      Directory('build/pack').deleteSync(recursive: true);
    }

    Directory('build/packages').renameSync('build/pack');
    // The devtools package build directory needs to reflect the latest
    // devtools_app package contents.
    if (Directory('../devtools/build').existsSync()) {
      Directory('../devtools/build').deleteSync(recursive: true);
    }

    Directory('build').renameSync('../devtools/build');

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
  }, timeout: const Timeout.factor(10));
}
