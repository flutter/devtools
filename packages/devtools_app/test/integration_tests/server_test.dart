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
import 'util.dart';

CliAppFixture appFixture;
DevToolsServerDriver server;
final Map<String, Completer<Map<String, dynamic>>> completers = {};
final StreamController<Map<String, dynamic>> eventController =
    StreamController.broadcast();
Stream<Map<String, dynamic>> get events => eventController.stream;
final Map<String, String> registeredServices = {};

void main() {
  final bool testInReleaseMode =
      Platform.environment['WEBDEV_RELEASE'] == 'true';

  setUp(() async {
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
      } else if (map.containsKey('event')) {
        eventController.add(map);
      }
    });

    await _startApp();
  });

  tearDown(() async {
    server?.kill();
    await appFixture?.teardown();
  });

  test('registers service', () async {
    final serverResponse =
        await _send('vm.register', {'uri': appFixture.serviceUri.toString()});
    expect(serverResponse['success'], isTrue);

    // Expect the VM service to see the launchDevTools service registered.
    expect(registeredServices, contains('launchDevTools'));
  }, timeout: const Timeout.factor(10));

  test('can bind to next available port', () async {
    final server1 = await DevToolsServerDriver.create(port: 8855);
    try {
      // Give first server chance to grab the port before we start the second.
      await shortDelay();
      final server2 =
          await DevToolsServerDriver.create(port: 8855, tryPorts: 2);
      try {
        final event1 = await server1.output
            .firstWhere((map) => map['event'] == 'server.started');
        final event2 = await server2.output
            .firstWhere((map) => map['event'] == 'server.started');

        expect(event1['params']['port'], equals(8855));
        expect(event2['params']['port'], equals(8856));
      } finally {
        server2.kill();
      }
    } finally {
      server1.kill();
    }
    // TODO(dantup): This test will fail until the devtools pubspec.yaml
    // references a version of devtools_server that has this support!
  }, skip: true, timeout: const Timeout.factor(10));

  group('Server API', () {
    test(
        'DevTools connects back to server API and registers that it is connected',
        () async {
      // Register the VM.
      await _send('vm.register', {'uri': appFixture.serviceUri.toString()});

      // Send a request to launch DevTools in a browser.
      await launchDevTools();

      final serverResponse =
          await _waitForClients(requiredConnectionState: true);
      expect(serverResponse, isNotNull);
      expect(serverResponse['clients'], hasLength(1));
      expect(serverResponse['clients'][0]['hasConnection'], isTrue);
      expect(serverResponse['clients'][0]['vmServiceUri'],
          equals(appFixture.serviceUri.toString()));
    }, timeout: const Timeout.factor(10));

    test('can launch on a specific page', () async {
      // Register the VM.
      await _send('vm.register', {'uri': appFixture.serviceUri.toString()});

      // Send a request to launch at a certain page.
      await launchDevTools(page: 'memory');

      final serverResponse = await _waitForClients(requiredPage: 'memory');
      expect(serverResponse, isNotNull);
      expect(serverResponse['clients'], hasLength(1));
      expect(serverResponse['clients'][0]['hasConnection'], isTrue);
      expect(serverResponse['clients'][0]['vmServiceUri'],
          equals(appFixture.serviceUri.toString()));
      expect(serverResponse['clients'][0]['currentPage'], equals('memory'));
    }, timeout: const Timeout.factor(10));

    test('can switch page', () async {
      await _send('vm.register', {'uri': appFixture.serviceUri.toString()});

      // Launch on the memory page and wait for the connection.
      await launchDevTools(page: 'memory');
      await _waitForClients(requiredPage: 'memory');

      // Re-launch, allowing reuse and with a different page.
      await launchDevTools(reuseWindows: true, page: 'performance');

      final serverResponse = await _waitForClients(requiredPage: 'performance');
      expect(serverResponse, isNotNull);
      expect(serverResponse['clients'], hasLength(1));
      expect(serverResponse['clients'][0]['hasConnection'], isTrue);
      expect(serverResponse['clients'][0]['vmServiceUri'],
          equals(appFixture.serviceUri.toString()));
      expect(
          serverResponse['clients'][0]['currentPage'], equals('performance'));
    }, timeout: const Timeout.factor(10));

    test('DevTools reports disconnects from a VM', () async {
      // Register the VM.
      await _send('vm.register', {'uri': appFixture.serviceUri.toString()});

      // Send a request to launch DevTools in a browser.
      await launchDevTools();

      // Wait for the DevTools to inform server that it's connected.
      await _waitForClients(requiredConnectionState: true);

      // Terminate the VM.
      await appFixture.teardown();

      // Ensure the client is marked as disconnected.
      final serverResponse =
          await _waitForClients(requiredConnectionState: false);
      expect(serverResponse['clients'], hasLength(1));
      expect(serverResponse['clients'][0]['hasConnection'], isFalse);
      expect(serverResponse['clients'][0]['vmServiceUri'], isNull);
    }, timeout: const Timeout.factor(10));

    test('server removes clients that disconnect from the API', () async {
      // TODO(dantup): This requires the ability for us to shut down Chrome,
      // probably via a command to the server, which needs
      // https://github.com/dart-lang/browser_launcher/pull/12
    }, timeout: const Timeout.factor(10), skip: true);

    test('Server reuses DevTools instance if already connected to same VM',
        () async {
      // Register the VM.
      await _send('vm.register', {'uri': appFixture.serviceUri.toString()});

      // Send a request to launch DevTools in a browser.
      await launchDevTools();

      {
        final serverResponse =
            await _waitForClients(requiredConnectionState: true);
        expect(serverResponse['clients'], hasLength(1));
      }

      // Request again, allowing reuse, and server emits an event saying the
      // window was reused.
      final launchResponse = await launchDevTools(reuseWindows: true);
      expect(launchResponse['reused'], isTrue);

      // Ensure there's still only one connection (eg. we didn't spawn a new one
      // we reused the existing one).
      final serverResponse =
          await _waitForClients(requiredConnectionState: true);
      expect(serverResponse['clients'], hasLength(1));
    }, timeout: const Timeout.factor(10));

    test('Server reuses DevTools instance if not connected to a VM', () async {
      // Register the VM.
      await _send('vm.register', {'uri': appFixture.serviceUri.toString()});

      // Send a request to launch DevTools in a browser.
      await launchDevTools();

      // Wait for the DevTools to inform server that it's connected.
      await _waitForClients(requiredConnectionState: true);

      // Terminate the VM.
      await appFixture.teardown();

      // Ensure the client is marked as disconnected.
      await _waitForClients(requiredConnectionState: false);

      // Start up a new app.
      await _startApp();
      await _send('vm.register', {'uri': appFixture.serviceUri.toString()});

      // Send a new request to launch.
      await launchDevTools(reuseWindows: true);

      // Ensure we now have a single connected client.
      final serverResponse =
          await _waitForClients(requiredConnectionState: true);
      expect(serverResponse['clients'], hasLength(1));
      expect(serverResponse['clients'][0]['hasConnection'], isTrue);
      expect(serverResponse['clients'][0]['vmServiceUri'],
          equals(appFixture.serviceUri.toString()));
    }, timeout: const Timeout.factor(10));
    // TODO(dantup): This test will fail until the devtools pubspec.yaml
    // references a version of devtools_server that has this support!
    // Usually we should only skip when not in release mode, since the API only
    // works in release mode.
  }, skip: true /*!testInReleaseMode*/);
}

Future<Map<String, dynamic>> launchDevTools({
  String page,
  bool reuseWindows = false,
}) async {
  final launchEvent = events.where((e) => e['event'] == 'client.launch').first;
  await appFixture.serviceConnection.callMethod(
    registeredServices['launchDevTools'],
    args: reuseWindows ? {'reuseWindows': true, 'page': page} : null,
  );
  final response = await launchEvent;
  return response['params'];
}

Future<void> _startApp() async {
  appFixture = await CliAppFixture.create('test/fixtures/empty_app.dart');

  // TODO(dantup): When the stable versions of Dart + Flutter are >= v3.22
  // of the VM Service (July 2019), the _Service option here can be removed.
  final serviceStreamName =
      await appFixture.serviceConnection.serviceStreamName;

  // Track services method names as they're registered.
  appFixture.serviceConnection
      .onEvent(serviceStreamName)
      .where((e) => e.kind == EventKind.kServiceRegistered)
      .listen((e) => registeredServices[e.service] = e.method);
  await appFixture.serviceConnection.streamListen(serviceStreamName);
}

int nextId = 0;
Future<Map<String, dynamic>> _send(String method,
    [Map<String, dynamic> params]) {
  final id = (nextId++).toString();
  completers[id] = Completer<Map<String, dynamic>>();
  server.write({'id': id.toString(), 'method': method, 'params': params});
  return completers[id].future;
}

// It may take time for the servers client list to be updated as the web app
// connects, so this helper just polls waiting for the expected state and
// then returns the client list.
Future<Map<String, dynamic>> _waitForClients({
  bool requiredConnectionState,
  String requiredPage,
}) async {
  Map<String, dynamic> serverResponse;
  await waitFor(
    () async {
      serverResponse = await _send('client.list');
      final clients = serverResponse['clients'];
      return clients is List &&
          clients.isNotEmpty &&
          (requiredPage == null ||
              clients.any((c) => c['currentPage'] == requiredPage)) &&
          (requiredConnectionState == null ||
              clients
                  .any((c) => c['hasConnection'] == requiredConnectionState));
    },
    timeout: const Duration(seconds: 10),
    timeoutMessage: 'Server did not return any known clients',
    delay: const Duration(seconds: 1),
  );
  return serverResponse;
}
