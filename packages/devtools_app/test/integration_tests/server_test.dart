// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart';

import '../support/cli_test_driver.dart';
import '../support/devtools_server_driver.dart';
import 'integration.dart';

void main() {
  CliAppFixture appFixture;
  DevToolsServerDriver server;
  String serviceStreamName;
  final Map<String, Completer<Map<String, dynamic>>> completers =
      <String, Completer<Map<String, dynamic>>>{};

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

    // Fail tests on any stderr.
    server.stderr.listen((text) => throw 'STDERR: $text');
    server.output.listen((map) {
      if (map.containsKey('id')) {
        if (map.containsKey('result')) {
          completers[map['id']].complete(map['result']);
        } else {
          completers[map['id']].completeError(map['error']);
        }
      } else {
        // Events (like 'server.started') are not currently used.
      }
    });

    // Start a test app we can use to connect to.
    appFixture = await CliAppFixture.create('test/fixtures/empty_app.dart');

    // TODO(dantup): When the stable versions of Dart + Flutter are >= v3.22
    // of the VM Service (July 2019), the _Service option here can be removed.
    serviceStreamName = await appFixture.serviceConnection.serviceStreamName;
  });

  tearDown(() async {
    server?.kill();
    await appFixture?.teardown();
  });

  int nextId = 0;
  Future<Map<String, dynamic>> _send(String method,
      [Map<String, dynamic> params]) {
    final id = (nextId++).toString();
    completers[id] = new Completer<Map<String, dynamic>>();
    server.write({'id': id.toString(), 'method': method, 'params': params});
    return completers[id].future;
  }

  // It may take time for the servers client list to be updated as the web app
  // connects, so this helper just polls waiting for the expected state and
  // then returns the client list.
  Future<Map<String, dynamic>> _waitForClients(
      {bool requiredConnectionState}) async {
    Map<String, dynamic> serverResponse;
    await waitFor(
      () async {
        serverResponse = await _send('clients.list');
        final clients = serverResponse['clients'];
        return clients is List &&
            clients.isNotEmpty &&
            (requiredConnectionState == null ||
                clients[0]['hasConnection'] == requiredConnectionState);
      },
      timeout: Duration(seconds: 10),
      timeoutMessage: 'Server did not return any known clients',
      delay: Duration(seconds: 1),
    );
    return serverResponse;
  }

  test('registers service', () async {
    // Track services as they're registered.
    final registeredServices = <String>{};
    appFixture.serviceConnection
        .onEvent(serviceStreamName)
        .where((e) => e.kind == EventKind.kServiceRegistered)
        .listen((e) => registeredServices.add(e.service));
    await appFixture.serviceConnection.streamListen(serviceStreamName);

    final serverResponse =
        await _send('vm.register', {'uri': appFixture.serviceUri.toString()});
    expect(serverResponse['success'], isTrue);

    // Expect the VM service to see the launchDevTools service registered.
    expect(registeredServices, contains('launchDevTools'));
  }, timeout: const Timeout.factor(10));

  test(
      'DevTools connects back to server API and registers that it is connected',
      () async {
    // Track services method names as they're registered.
    final registeredServices = <String, String>{};
    appFixture.serviceConnection
        .onEvent(serviceStreamName)
        .where((e) => e.kind == EventKind.kServiceRegistered)
        .listen((e) => registeredServices[e.service] = e.method);
    await appFixture.serviceConnection.streamListen(serviceStreamName);

    // Register the VM.
    await _send('vm.register', {'uri': appFixture.serviceUri.toString()});

    // Send a request to launch DevTools in a browser.
    await appFixture.serviceConnection
        .callMethod(registeredServices['launchDevTools'], args: {});

    final serverResponse = await _waitForClients(requiredConnectionState: true);
    expect(serverResponse, isNotNull);
    expect(serverResponse['clients'], hasLength(1));
    expect(serverResponse['clients'][0]['hasConnection'], isTrue);
    expect(serverResponse['clients'][0]['vmServiceUri'],
        equals(appFixture.serviceUri.toString()));
    // TODO(dantup): This test will fail until the devtools pubspec.yaml
    // references a version of devtools_server that has this support!
  }, timeout: const Timeout.factor(10), skip: true);
}
