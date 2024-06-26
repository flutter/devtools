// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/helpers.dart';
import 'package:devtools_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// To run:
// dart run integration_test/run_tests.dart --target=integration_test/test/live_connection/service_connection_test.dart

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

  testWidgets('initial service connection state', (tester) async {
    await pumpAndConnectDevTools(tester, testApp);

    // Await a delay to ensure the service extensions have had a chance to
    // be called. This delay may be able to be shortened if doing so does
    // not cause bot flakiness.
    await tester.pump(longDuration);

    // Ensure all futures are completed before running checks.
    await serviceConnection.serviceManager.service!.allFuturesCompleted;

    logStatus('verify the vm service calls that occur on connect');
    final vmServiceCallCount =
        serviceConnection.serviceManager.service!.vmServiceCallCount;
    expect(
      // Use a range instead of an exact number because service extension
      // calls are not consistent. This will still catch any spurious calls
      // that are unintentionally added at start up.
      const Range(35, 70).contains(vmServiceCallCount),
      isTrue,
      reason: 'Unexpected number of vm service calls upon connection: '
          '$vmServiceCallCount. If this is expected, please update this test '
          'to the new expected number of calls. Here are the calls for this '
          'test run:\n ${serviceConnection.serviceManager.service!.vmServiceCalls.toString()}',
    );

    // Check the ordering of the vm service calls we can expect to occur
    // in a stable order.
    expect(
      serviceConnection.serviceManager.service!.vmServiceCalls
          // Filter out unawaited streamListen calls.
          .where((call) => call != 'streamListen')
          .toList()
          .sublist(0, 8),
      equals([
        'getSupportedProtocols',
        'getVersion',
        'setFlag',
        'requirePermissionToResume',
        'getFlagList',
        'getDartDevelopmentServiceVersion',
        'getDartDevelopmentServiceVersion',
        'getVM',
      ]),
      reason: 'Unexpected order of vm service calls upon connection. '
          'Here are the calls for this test run:\n '
          '${serviceConnection.serviceManager.service!.vmServiceCalls.toString()}',
    );

    expect(
      serviceConnection.serviceManager.service!.vmServiceCalls
          .where((call) => call == 'streamListen')
          .toList()
          .length,
      equals(10),
    );

    logStatus('verify managers have all been initialized');
    expect(serviceConnection.serviceManager.isolateManager, isNotNull);
    expect(serviceConnection.serviceManager.serviceExtensionManager, isNotNull);
    expect(serviceConnection.vmFlagManager, isNotNull);
    expect(
      serviceConnection.serviceManager.isolateManager.isolates.value,
      isNotEmpty,
    );
    expect(serviceConnection.vmFlagManager.flags.value, isNotNull);

    if (serviceConnection.serviceManager.isolateManager.selectedIsolate.value ==
        null) {
      await whenValueNonNull(
        serviceConnection.serviceManager.isolateManager.selectedIsolate,
      );
    }

    await disconnectFromTestApp(tester);
  });
}
