// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/service/service_extensions.dart' as extensions;
import 'package:devtools_app/src/shared/eval_on_dart_library.dart';
import 'package:devtools_test/devtools_integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vm_service/vm_service.dart';

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
    await serviceManager.service!.allFuturesCompleted;

    logStatus('verify the number of vm service calls on connect');
    final vmServiceCallCount = serviceManager.service!.vmServiceCallCount;
    expect(
      // Use a range instead of an exact number because service extension
      // calls are not consistent. This will still catch any spurious calls
      // that are unintentionally added at start up.
      const Range(50, 60).contains(vmServiceCallCount),
      isTrue,
      reason: 'Unexpected number of vm service calls upon connection: '
          '$vmServiceCallCount. If this is expected, please update this test '
          'to the new expected number of calls. Here are the calls for this '
          'test run:\n ${serviceManager.service!.vmServiceCalls.toString()}',
    );
    // Check the ordering of the vm service calls we can expect to occur
    // in a stable order.
    expect(
      serviceManager.service!.vmServiceCalls
          // Filter out unawaited streamListen calls.
          .where((call) => call != 'streamListen')
          .toList()
          .sublist(0, 5),
      equals([
        'getSupportedProtocols',
        'getVersion',
        'getFlagList',
        'getVM',
        'getIsolate',
      ]),
    );

    expect(
      serviceManager.service!.vmServiceCalls
          .where((call) => call == 'streamListen')
          .toList()
          .length,
      equals(10),
    );

    logStatus('verify managers have all been initialized');
    expect(serviceManager.isolateManager, isNotNull);
    expect(serviceManager.serviceExtensionManager, isNotNull);
    expect(serviceManager.vmFlagManager, isNotNull);
    expect(serviceManager.isolateManager.isolates.value, isNotEmpty);
    expect(serviceManager.vmFlagManager.flags.value, isNotNull);

    if (serviceManager.isolateManager.selectedIsolate.value == null) {
      await whenValueNonNull(serviceManager.isolateManager.selectedIsolate);
    }
  });
}

