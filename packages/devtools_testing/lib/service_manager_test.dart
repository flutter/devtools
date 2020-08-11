// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member

@TestOn('vm')
import 'dart:async';
import 'dart:io';

import 'package:devtools_app/src/eval_on_dart_library.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_extensions.dart' as extensions;
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/service_registrations.dart' as registrations;
import 'package:devtools_app/src/vm_service_wrapper.dart';
import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart';

import 'support/constants.dart';
import 'support/flutter_test_driver.dart';
import 'support/flutter_test_environment.dart';

// Error codes defined by
// https://www.jsonrpc.org/specification#error_object
const jsonRpcInvalidParamsCode = -32602;

Future<void> runServiceManagerTests(FlutterTestEnvironment env) async {
  group('ServiceConnectionManager', () {
    tearDownAll(() async {
      await env.tearDownEnvironment(force: true);
    });

    test('vmServiceOpened', () async {
      await env.setupEnvironment();

      expect(serviceManager.service, equals(env.service));
      expect(serviceManager.isolateManager, isNotNull);
      expect(serviceManager.serviceExtensionManager, isNotNull);
      expect(serviceManager.vmFlagManager, isNotNull);
      expect(serviceManager.isolateManager.isolates, isNotEmpty);
      expect(serviceManager.vmFlagManager.flags.value, isNotNull);

      if (serviceManager.isolateManager.selectedIsolate == null) {
        await serviceManager.isolateManager.onSelectedIsolateChanged
            .firstWhere((ref) => ref != null);
      }

      await env.tearDownEnvironment();
    });

    test('invalid setBreakpoint throws exception', () async {
      await env.setupEnvironment();

      await expectLater(
        serviceManager.service.addBreakpoint(
            serviceManager.isolateManager.selectedIsolate.id,
            'fake-script-id',
            1),
        throwsA(const TypeMatcher<RPCError>()
            .having((e) => e.code, 'code', equals(jsonRpcInvalidParamsCode))),
      );

      await env.tearDownEnvironment();
    });

    test('toggle boolean service extension', () async {
      await env.setupEnvironment();
      await serviceManager.service.allFuturesCompleted;

      final extensionName = extensions.debugPaint.extension;
      const evalExpression = 'debugPaintSizeEnabled';
      final library = EvalOnDartLibrary(
        [
          'package:flutter/src/rendering/debug.dart',
          'package:flutter_web/src/rendering/debug.dart',
        ],
        env.service,
      );

      await _verifyExtensionStateOnTestDevice(evalExpression, 'false', library);
      await _verifyInitialExtensionStateInServiceManager(extensionName);

      // Enable the service extension via ServiceExtensionManager.
      await serviceManager.serviceExtensionManager.setServiceExtensionState(
        extensionName,
        true,
        true,
      );

      await _verifyExtensionStateOnTestDevice(evalExpression, 'true', library);
      await _verifyExtensionStateInServiceManager(extensionName, true, true);

      await env.tearDownEnvironment();
    });

    test('toggle String service extension', () async {
      await env.setupEnvironment();
      await serviceManager.service.allFuturesCompleted;

      final extensionName = extensions.togglePlatformMode.extension;
      const evalExpression = 'defaultTargetPlatform.toString()';
      final library = EvalOnDartLibrary(
        [
          'package:flutter_web/src/foundation/platform.dart',
          'package:flutter/src/foundation/platform.dart',
        ],
        env.service,
      );

      await _verifyExtensionStateOnTestDevice(
        evalExpression,
        'TargetPlatform.android',
        library,
      );
      await _verifyExtensionStateInServiceManager(
        extensionName,
        true,
        'android',
      );

      // Enable the service extension via ServiceExtensionManager.
      await serviceManager.serviceExtensionManager.setServiceExtensionState(
        extensionName,
        true,
        'iOS',
      );

      await _verifyExtensionStateOnTestDevice(
        evalExpression,
        'TargetPlatform.iOS',
        library,
      );
      await _verifyExtensionStateInServiceManager(extensionName, true, 'iOS');

      await env.tearDownEnvironment();
    });

    test('toggle numeric service extension', () async {
      await env.setupEnvironment();
      await serviceManager.service.allFuturesCompleted;

      final extensionName = extensions.slowAnimations.extension;
      const evalExpression = 'timeDilation';
      final library = EvalOnDartLibrary(
        [
          'package:flutter_web/src/scheduler/binding.dart',
          'package:flutter/src/scheduler/binding.dart',
        ],
        env.service,
      );

      await _verifyExtensionStateOnTestDevice(evalExpression, '1.0', library);
      await _verifyInitialExtensionStateInServiceManager(extensionName);

      // Enable the service extension via ServiceExtensionManager.
      await serviceManager.serviceExtensionManager.setServiceExtensionState(
        extensionName,
        true,
        5.0,
      );

      await _verifyExtensionStateOnTestDevice(evalExpression, '5.0', library);
      await _verifyExtensionStateInServiceManager(extensionName, true, 5.0);

      await env.tearDownEnvironment();
    });

    test('callService', () async {
      await env.setupEnvironment();

      final registeredService = serviceManager
              .registeredMethodsForService[registrations.hotReload.service] ??
          const [];
      expect(registeredService, isNotEmpty);

      await serviceManager.callService(
        registrations.hotReload.service,
        isolateId: serviceManager.isolateManager.selectedIsolate.id,
      );

      await env.tearDownEnvironment();
    });

    test('callService throws exception', () async {
      await env.setupEnvironment();

      // Service with 0 registrations.
      await expectLater(
          serviceManager.callService('fakeMethod'), throwsException);

      await env.tearDownEnvironment();
    });

    test('hotReload', () async {
      await env.setupEnvironment();

      await serviceManager.performHotReload();

      await env.tearDownEnvironment();
    });

    // TODO(jacobr): uncomment out the hotRestart tests once
    // https://github.com/flutter/devtools/issues/337 is fixed.
    /*
    test('hotRestart', () async {
      await env.setupEnvironment();

      const evalExpression = 'topLevelFieldForTest';
      final library = EvalOnDartLibrary(
        'package:flutter_app/main.dart',
        env.service,
      );

      // Verify topLevelFieldForTest is false initially.
      final initialResult = await library.eval(evalExpression, isAlive: null);
      expect(initialResult.runtimeType, equals(InstanceRef));
      expect(initialResult.valueAsString, equals('false'));

      // Set field to true by calling the service extension.
      await library.eval('$evalExpression = true', isAlive: null);

      // Verify topLevelFieldForTest is now true.
      final intermediateResult =
          await library.eval(evalExpression, isAlive: null);
      expect(intermediateResult.runtimeType, equals(InstanceRef));
      expect(intermediateResult.valueAsString, equals('true'));

      await serviceManager.performHotRestart();

      /// After the hot restart some existing calls to the vm service may
      /// timeout and that is ok.
      serviceManager.service.doNotWaitForPendingFuturesBeforeExit();

      // Verify topLevelFieldForTest is false again after hot restart.
      final finalResult = await library.eval(evalExpression, isAlive: null);
      expect(finalResult.runtimeType, equals(InstanceRef));
      expect(finalResult.valueAsString, equals('false'));

      await env.tearDownEnvironment();
    });
    */

    test('getDisplayRefreshRate', () async {
      await env.setupEnvironment();

      expect(await serviceManager.getDisplayRefreshRate(), equals(60));

      await env.tearDownEnvironment();
    });
  }, timeout: const Timeout.factor(4));

  group('VmFlagManager', () {
    tearDownAll(() async {
      await env.tearDownEnvironment(force: true);
    });

    test('flags initialized on vm service opened', () async {
      await env.setupEnvironment();

      expect(serviceManager.service, equals(env.service));
      expect(serviceManager.vmFlagManager, isNotNull);
      expect(serviceManager.vmFlagManager.flags.value, isNotNull);

      await env.tearDownEnvironment();
    });

    test('notifies on flag change', () async {
      await env.setupEnvironment();
      const profiler = 'profiler';

      final flagManager = serviceManager.vmFlagManager;
      final initialFlags = flagManager.flags.value;
      final profilerFlagNotifier = flagManager.flag(profiler);
      expect(profilerFlagNotifier.value.valueAsString, equals('true'));

      await serviceManager.service.setFlag(profiler, 'false');
      expect(profilerFlagNotifier.value.valueAsString, equals('false'));

      // Await a delay so the new flags have time to be pulled and set.
      await Future.delayed(const Duration(milliseconds: 5000));
      final newFlags = flagManager.flags.value;
      expect(newFlags, isNot(equals(initialFlags)));

      await env.tearDownEnvironment();
    });
  }, timeout: const Timeout.factor(4));
}

Future<void> runServiceManagerTestsWithDriverFactory(
    {FlutterDriverFactory flutterDriverFactory =
        defaultFlutterRunDriver}) async {
  group('ServiceConnectionManager - restoring device-enabled extension', () {
    FlutterRunTestDriver _flutter;
    String _flutterIsolateId;
    VmServiceWrapper service;

    setUp(() async {
      _flutter = flutterDriverFactory(
          Directory('$devtoolsTestingPackageRoot/fixtures/flutter_app'));
      await _flutter.run(
          runConfig: const FlutterRunConfiguration(withDebugger: true));
      _flutterIsolateId = await _flutter.getFlutterIsolateId();

      service = _flutter.vmService;
      setGlobal(ServiceConnectionManager, ServiceConnectionManager());
    });

    tearDown(() async {
      await service.allFuturesCompleted;
      await _flutter.stop();
    });

    /// Helper method to call an extension on the test device and verify that
    /// the device reflects the new extension state.
    Future<void> _enableExtensionOnTestDevice(
      extensions.ServiceExtensionDescription extensionDescription,
      Map<String, dynamic> args,
      String evalExpression,
      EvalOnDartLibrary library, {
      String newValue,
      String oldValue,
    }) async {
      if (extensionDescription
          is extensions.ToggleableServiceExtensionDescription) {
        newValue ??= extensionDescription.enabledValue.toString();
        oldValue ??= extensionDescription.disabledValue.toString();
      }

      // Verify initial extension state on test device.
      await _verifyExtensionStateOnTestDevice(
        evalExpression,
        oldValue,
        library,
      );

      // Enable service extension on test device.
      await _flutter.vmService.callServiceExtension(
        extensionDescription.extension,
        isolateId: _flutterIsolateId,
        args: args,
      );

      // Verify extension state after calling the service extension.
      await _verifyExtensionStateOnTestDevice(
        evalExpression,
        newValue,
        library,
      );
    }

    test('all extension types', () async {
      // Enable a boolean extension on the test device.
      final boolExtensionDescription = extensions.debugPaint;
      final boolArgs = {'enabled': true};
      const boolEvalExpression = 'debugPaintSizeEnabled';
      final boolLibrary = EvalOnDartLibrary(
        [
          'package:flutter/src/rendering/debug.dart',
          'package:flutter_web/src/rendering/debug.dart',
        ],
        service,
        isolateId: _flutterIsolateId,
      );

      await _enableExtensionOnTestDevice(
        boolExtensionDescription,
        boolArgs,
        boolEvalExpression,
        boolLibrary,
      );

      // Enable a String extension on the test device.
      final stringExtensionDescription = extensions.togglePlatformMode;
      final stringArgs = {'value': stringExtensionDescription.values[0]};
      const stringEvalExpression = 'defaultTargetPlatform.toString()';
      final stringLibrary = EvalOnDartLibrary(
        [
          'package:flutter/src/foundation/platform.dart',
          'package:flutter_web/src/foundation/platform.dart',
        ],
        service,
        isolateId: _flutterIsolateId,
      );
      await _enableExtensionOnTestDevice(
        stringExtensionDescription,
        stringArgs,
        stringEvalExpression,
        stringLibrary,
        newValue: 'TargetPlatform.iOS',
        oldValue: 'TargetPlatform.android',
      );

      // Enable a numeric extension on the test device.
      final numericExtensionDescription = extensions.slowAnimations;
      final numericArgs = {
        numericExtensionDescription.extension.substring(
                numericExtensionDescription.extension.lastIndexOf('.') + 1):
            numericExtensionDescription.enabledValue
      };
      const numericEvalExpression = 'timeDilation';
      final numericLibrary = EvalOnDartLibrary(
        [
          'package:flutter/src/scheduler/binding.dart',
          'package:flutter_web/src/scheduler/binding.dart',
        ],
        service,
        isolateId: _flutterIsolateId,
      );
      await _enableExtensionOnTestDevice(
        numericExtensionDescription,
        numericArgs,
        numericEvalExpression,
        numericLibrary,
      );

      // Open the VmService and verify that the enabled extension states are
      // reflected in [ServiceExtensionManager].
      await serviceManager.vmServiceOpened(
        service,
        onClosed: Completer().future,
      );
      await serviceManager
          .serviceExtensionManager.extensionStatesUpdated.future;
      // TODO(kenz): Uncomment this once
      // https://github.com/flutter/devtools/issues/1351 is fixed.
      /*
      await _verifyExtensionStateInServiceManager(
        boolExtensionDescription.extension,
        true,
        boolExtensionDescription.enabledValue,
      );
      */
      await _verifyExtensionStateInServiceManager(
        stringExtensionDescription.extension,
        true,
        stringExtensionDescription.values[0],
      );
      await _verifyExtensionStateInServiceManager(
        numericExtensionDescription.extension,
        true,
        numericExtensionDescription.enabledValue,
      );
    });
  }, timeout: const Timeout.factor(8));
}

Future<void> _verifyExtensionStateOnTestDevice(String evalExpression,
    String expectedResult, EvalOnDartLibrary library) async {
  final result = await library.eval(evalExpression, isAlive: null);
  if (result is InstanceRef) {
    expect(result.valueAsString, equals(expectedResult));
  }
}

Future<void> _verifyInitialExtensionStateInServiceManager(
    String extensionName) async {
  // For all service extensions, the initial state in ServiceExtensionManager
  // should be disabled with value null.
  await _verifyExtensionStateInServiceManager(extensionName, false, null);
}

Future<void> _verifyExtensionStateInServiceManager(
    String extensionName, bool enabled, dynamic value) async {
  final StreamSubscription<ServiceExtensionState> stream = serviceManager
      .serviceExtensionManager
      .getServiceExtensionState(extensionName, null);

  final Completer<ServiceExtensionState> stateCompleter = Completer();
  stream.onData((ServiceExtensionState state) {
    stateCompleter.complete(state);
    stream.cancel();
  });

  final ServiceExtensionState state = await stateCompleter.future;
  expect(state.enabled, equals(enabled));
  expect(state.value, equals(value));
}
