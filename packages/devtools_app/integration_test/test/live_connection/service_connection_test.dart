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

  testWidgets('can call service extensions', (tester) async {
    await pumpAndConnectDevTools(tester, testApp);
    await tester.pump(longDuration);

    // Ensure all futures are completed before running checks.
    await serviceManager.service!.allFuturesCompleted;

    logStatus('verify toggling a boolean service extension');
    final extensionName = extensions.debugPaint.extension;
    const evalExpression = 'debugPaintSizeEnabled';
    final library = EvalOnDartLibrary(
      'package:flutter/src/rendering/debug.dart',
      serviceManager.service!,
    );

    await _serviceExtensionAvailable(extensionName);

    logStatus('verify initial state on device is false');

    // This chunk of code is behaving weirdly
    logStatus('before eval $evalExpression');
    final result = await library.eval(evalExpression, isAlive: null);
    logStatus('after eval $evalExpression');
    if (result is InstanceRef) {
      logStatus(
        'result.valueAsString: ${result.valueAsString}, expectedResult: false',
      );
      if (result.valueAsString == 'false') {
        logStatus('this expectation is true');
      }
      // This expectation is failing after the test finishes, even though it
      // does not fail during the test execution.
      logStatus(
          'before calling "expect(result.valueAsString, equals(\'false\'))"');
      expect(result.valueAsString, equals('false'));
      logStatus(
          'after calling "expect(result.valueAsString, equals(\'false\'))"');
    }
    // end chunk

    // await _verifyExtensionStateOnTestDevice(
    //   evalExpression: evalExpression,
    //   expectedResult: 'false',
    //   library: library,
    // );

    logStatus('verify initial state in service manager is false');
    await _verifyInitialExtensionStateInServiceManager(extensionName);

    // The test only fails when the following block is present, but oddly it
    // fails above at line 127 `expect(result.valueAsString, equals('false'));`
    // however it fails at line 127 after the test has already completed and the
    // prints show we have already successfully made it past line 127.
    logStatus('enable the service extension via ServiceExtensionManager');
    await serviceManager.serviceExtensionManager.setServiceExtensionState(
      extensionName,
      enabled: true,
      value: true,
    );

    logStatus('at the end of the test');
  });

}

/// Returns a future that completes when the service extension is available.
Future<void> _serviceExtensionAvailable(String extensionName) async {
  final listenable =
      serviceManager.serviceExtensionManager.hasServiceExtension(extensionName);

  final completer = Completer<void>();
  void listener() {
    if (listenable.value && !completer.isCompleted) {
      completer.complete();
    }
  }

  listener();
  listenable.addListener(listener);
  await completer.future;
  listenable.removeListener(listener);
}

Future<void> _verifyExtensionStateOnTestDevice({
  required String evalExpression,
  required String? expectedResult,
  required EvalOnDartLibrary library,
}) async {
  logStatus('before eval $evalExpression');
  final result = await library.eval(evalExpression, isAlive: null);
  logStatus('after eval $evalExpression');
  if (result is InstanceRef) {
    logStatus(
      'result.valueAsString: ${result.valueAsString}, expectedResult: $expectedResult',
    );
    expect(result.valueAsString, equals(expectedResult));
    logStatus(
        'after result expectation - result ${result.valueAsString == expectedResult}');
  }
}

Future<void> _verifyInitialExtensionStateInServiceManager(
  String extensionName,
) async {
  // For all service extensions, the initial state in ServiceExtensionManager
  // should be disabled with value null.
  await _verifyExtensionStateInServiceManager(
    extensionName,
    enabled: false,
    value: null,
  );
}

Future<void> _verifyExtensionStateInServiceManager(
  String extensionName, {
  required bool enabled,
  required Object? value,
}) async {
  logStatus(
      '_verifyExtensionStateInServiceManager, $extensionName - enabled: $enabled, value: $value');
  final stateListenable = serviceManager.serviceExtensionManager
      .getServiceExtensionState(extensionName);

  // Wait for the service extension state to match the expected value.
  final Completer<ServiceExtensionState> stateCompleter = Completer();
  void stateListener() {
    print('in stateListener - ${stateListenable.value.value}');
    if (stateListenable.value.value == value) {
      stateCompleter.complete(stateListenable.value);
    }
  }

  stateListenable.addListener(stateListener);
  stateListener();

  logStatus('before await future in verify in servicemanager fx');
  final ServiceExtensionState state = await stateCompleter.future;
  logStatus('after await future in verify in servicemanager fx');
  stateListenable.removeListener(stateListener);
  expect(state.enabled, equals(enabled));
  expect(state.value, equals(value));
}
