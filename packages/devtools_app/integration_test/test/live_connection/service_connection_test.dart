// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/service/service_extension_widgets.dart';
import 'package:devtools_app/src/service/service_extensions.dart' as extensions;
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_test/helpers.dart';
import 'package:devtools_test/integration_test.dart';
import 'package:flutter/widgets.dart';
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
    await serviceConnection.serviceManager.service!.allFuturesCompleted;

    logStatus('verify the vm service calls that occur on connect');
    final vmServiceCallCount =
        serviceConnection.serviceManager.service!.vmServiceCallCount;
    expect(
      // Use a range instead of an exact number because service extension
      // calls are not consistent. This will still catch any spurious calls
      // that are unintentionally added at start up.
      const Range(40, 70).contains(vmServiceCallCount),
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

  testWidgets('can call services and service extensions', (tester) async {
    await pumpAndConnectDevTools(tester, testApp);
    await tester.pump(longDuration);

    // TODO(kenz): re-work this integration test so that we do not have to be
    // on the inspector screen for this to pass.
    await switchToScreen(
      tester,
      tabIcon: ScreenMetaData.inspector.icon!,
      screenId: ScreenMetaData.inspector.id,
    );
    await tester.pump(longDuration);

    // Ensure all futures are completed before running checks.
    await serviceConnection.serviceManager.service!.allFuturesCompleted;

    logStatus('verify Flutter framework service extensions');
    await _verifyBooleanExtension(tester);
    await _verifyNumericExtension(tester);
    await _verifyStringExtension(tester);

    logStatus('verify Flutter engine service extensions');
    expect(
      await serviceConnection.queryDisplayRefreshRate,
      equals(60),
    );

    logStatus('verify services that are registered to exactly one client');
    await _verifyHotReloadAndHotRestart();
    await expectLater(
      serviceConnection.serviceManager.callService('fakeMethod'),
      throwsException,
    );

    await disconnectFromTestApp(tester);
  });

  testWidgets('loads initial extension states from device', (tester) async {
    await pumpAndConnectDevTools(tester, testApp);
    await tester.pump(longDuration);

    // Ensure all futures are completed before running checks.
    final service = serviceConnection.serviceManager.service!;
    await service.allFuturesCompleted;

    final serviceExtensionsToEnable = [
      (extensions.debugPaint.extension, true),
      (extensions.slowAnimations.extension, 5.0),
      (extensions.togglePlatformMode.extension, 'iOS'),
    ];

    logStatus('enabling service extensions on the test device');
    // Enable a service extension of each type (boolean, numeric, string).
    for (final ext in serviceExtensionsToEnable) {
      await serviceConnection.serviceManager.serviceExtensionManager
          .setServiceExtensionState(
        ext.$1,
        enabled: true,
        value: ext.$2,
      );
    }

    logStatus('disconnecting from the test device');
    await disconnectFromTestApp(tester);

    for (final ext in serviceExtensionsToEnable) {
      expect(
        serviceConnection.serviceManager.serviceExtensionManager
            .isServiceExtensionAvailable(ext.$1),
        isFalse,
      );
    }

    logStatus('reconnecting to the test device');
    await connectToTestApp(tester, testApp);

    logStatus('verify extension states have been restored from the device');
    for (final ext in serviceExtensionsToEnable) {
      expect(
        serviceConnection.serviceManager.serviceExtensionManager
            .isServiceExtensionAvailable(ext.$1),
        isTrue,
      );
      await _verifyExtensionStateInServiceManager(
        ext.$1,
        enabled: true,
        value: ext.$2,
      );
    }

    await disconnectFromTestApp(tester);
  });
}

Future<void> _verifyBooleanExtension(WidgetTester tester) async {
  final extensionName = extensions.debugPaint.extension;
  const evalExpression = 'debugPaintSizeEnabled';
  final library = EvalOnDartLibrary(
    'package:flutter/src/rendering/debug.dart',
    serviceConnection.serviceManager.service!,
    serviceManager: serviceConnection.serviceManager,
  );
  await _verifyExtension(
    tester,
    extensionName: extensionName,
    evalExpression: evalExpression,
    library: library,
    initialValue: false,
    newValue: true,
  );
}

Future<void> _verifyNumericExtension(WidgetTester tester) async {
  final extensionName = extensions.slowAnimations.extension;
  const evalExpression = 'timeDilation';
  final library = EvalOnDartLibrary(
    'package:flutter/src/scheduler/binding.dart',
    serviceConnection.serviceManager.service!,
    serviceManager: serviceConnection.serviceManager,
  );
  await _verifyExtension(
    tester,
    extensionName: extensionName,
    evalExpression: evalExpression,
    library: library,
    initialValue: 1.0,
    newValue: 5.0,
    initialValueOnDevice: '1.0',
    newValueOnDevice: '5.0',
  );
}

Future<void> _verifyStringExtension(WidgetTester tester) async {
  final extensionName = extensions.togglePlatformMode.extension;
  await _serviceExtensionAvailable(extensionName);
  const evalExpression = 'defaultTargetPlatform.toString()';
  final library = EvalOnDartLibrary(
    'package:flutter/src/foundation/platform.dart',
    serviceConnection.serviceManager.service!,
    serviceManager: serviceConnection.serviceManager,
  );
  await _verifyExtension(
    tester,
    extensionName: extensionName,
    evalExpression: evalExpression,
    library: library,
    initialValue: 'android',
    newValue: 'iOS',
    initialValueOnDevice: 'TargetPlatform.android',
    newValueOnDevice: 'TargetPlatform.iOS',
    initialValueInServiceManager: (true, 'android'),
    // TODO(https://github.com/flutter/devtools/issues/2780): change this
    // extension from the DevTools UI when it has a button in the inspector.
    toggleExtensionFromUi: false,
  );
}

Future<void> _verifyHotReloadAndHotRestart() async {
  const evalExpression = 'topLevelFieldForTest';
  final library = EvalOnDartLibrary(
    'package:flutter_app/main.dart',
    serviceConnection.serviceManager.service!,
    serviceManager: serviceConnection.serviceManager,
  );

  // Verify the initial value of [topLevelFieldForTest].
  var value = await library.eval(evalExpression, isAlive: null);
  expect(value.runtimeType, InstanceRef);
  expect(value!.valueAsString, 'false');

  // Change the value of [topLevelFieldForTest].
  await library.eval('$evalExpression = true', isAlive: null);

  // Verify the value of [topLevelFieldForTest] is now changed.
  value = await library.eval(evalExpression, isAlive: null);
  expect(value.runtimeType, InstanceRef);
  expect(value!.valueAsString, 'true');

  await serviceConnection.serviceManager.performHotReload();

  // Verify the value of [topLevelFieldForTest] is still changed after hot
  // reload.
  value = await library.eval(evalExpression, isAlive: null);
  expect(value.runtimeType, InstanceRef);
  expect(value!.valueAsString, 'true');

  await serviceConnection.serviceManager.performHotRestart();

  // Verify the value of [topLevelFieldForTest] is back to its original value
  // after hot restart.
  value = await library.eval(evalExpression, isAlive: null);
  expect(value.runtimeType, InstanceRef);
  expect(value!.valueAsString, 'false');
}

Future<void> _verifyExtension(
  WidgetTester tester, {
  required String extensionName,
  required String evalExpression,
  required EvalOnDartLibrary library,
  required Object initialValue,
  required Object newValue,
  (bool, Object?)? initialValueInServiceManager,
  String? initialValueOnDevice,
  String? newValueOnDevice,
  bool toggleExtensionFromUi = true,
}) async {
  await _serviceExtensionAvailable(extensionName);

  await _verifyExtensionStateOnTestDevice(
    evalExpression: evalExpression,
    expectedResult: initialValueOnDevice ?? initialValue.toString(),
    library: library,
  );
  await _verifyExtensionStateInServiceManager(
    extensionName,
    enabled: initialValueInServiceManager?.$1 ?? false,
    value: initialValueInServiceManager?.$2,
  );

  // Enable the service extension state from the service manager.
  await serviceConnection.serviceManager.serviceExtensionManager
      .setServiceExtensionState(
    extensionName,
    enabled: true,
    value: newValue,
  );

  await _verifyExtensionStateOnTestDevice(
    evalExpression: evalExpression,
    expectedResult: newValueOnDevice ?? newValue.toString(),
    library: library,
  );
  await _verifyExtensionStateInServiceManager(
    extensionName,
    enabled: true,
    value: newValue,
  );

  if (toggleExtensionFromUi) {
    // Disable the service extension state from the UI.
    await _changeServiceExtensionFromButton(
      extensionName,
      evalExpression: evalExpression,
      library: library,
      expectedResultOnDevice: initialValueOnDevice ?? initialValue.toString(),
      expectedResultInServiceManager: (false, initialValue),
      tester: tester,
    );
  }
}

Future<void> _changeServiceExtensionFromButton(
  String extensionName, {
  required String evalExpression,
  required EvalOnDartLibrary library,
  required String? expectedResultOnDevice,
  required (bool, Object?) expectedResultInServiceManager,
  required WidgetTester tester,
}) async {
  final serviceExtensionButtons = tester
      .widgetList<ServiceExtensionButton>(find.byType(ServiceExtensionButton));
  final button = serviceExtensionButtons.firstWhereOrNull(
    (b) => b.extensionState.description.extension == extensionName,
  );
  expect(button, isNotNull);
  await tester.tap(find.byWidget(button as Widget));
  await tester.pumpAndSettle(shortPumpDuration);

  await _verifyExtensionStateOnTestDevice(
    evalExpression: evalExpression,
    expectedResult: expectedResultOnDevice,
    library: library,
  );
  await _verifyExtensionStateInServiceManager(
    extensionName,
    enabled: expectedResultInServiceManager.$1,
    value: expectedResultInServiceManager.$2,
  );
}

/// Returns a future that completes when the service extension is available.
Future<void> _serviceExtensionAvailable(String extensionName) async {
  final listenable = serviceConnection.serviceManager.serviceExtensionManager
      .hasServiceExtension(extensionName);

  final completer = Completer<void>();
  void listener() {
    if (listenable.value) {
      completer.safeComplete();
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
  final result = await library.eval(evalExpression, isAlive: null);
  if (result is InstanceRef) {
    expect(result.valueAsString, equals(expectedResult));
  }
}

Future<void> _verifyExtensionStateInServiceManager(
  String extensionName, {
  required bool enabled,
  required Object? value,
}) async {
  final stateListenable = serviceConnection
      .serviceManager.serviceExtensionManager
      .getServiceExtensionState(extensionName);

  // Wait for the service extension state to match the expected value.
  final Completer<ServiceExtensionState> stateCompleter = Completer();
  void stateListener() {
    if (stateListenable.value.value == value) {
      stateCompleter.complete(stateListenable.value);
    }
  }

  stateListenable.addListener(stateListener);
  stateListener();

  final ServiceExtensionState state = await stateCompleter.future;
  stateListenable.removeListener(stateListener);
  expect(state.enabled, equals(enabled));
  expect(state.value, equals(value));
}
