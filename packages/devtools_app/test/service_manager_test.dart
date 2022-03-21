// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

@TestOn('vm')
import 'dart:async';

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/primitives/utils.dart';
import 'package:devtools_app/src/service/service_extension_manager.dart';
import 'package:devtools_app/src/service/service_extensions.dart' as extensions;
import 'package:devtools_app/src/service/service_registrations.dart'
    as registrations;
import 'package:devtools_app/src/shared/eval_on_dart_library.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import 'test_infra/flutter_test_driver.dart' show FlutterRunConfiguration;
import 'test_infra/flutter_test_environment.dart';

// Error codes defined by
// https://www.jsonrpc.org/specification#error_object
const jsonRpcInvalidParamsCode = -32602;

void main() async {
  setGlobal(IdeTheme, IdeTheme());
  final FlutterTestEnvironment env = FlutterTestEnvironment(
    const FlutterRunConfiguration(withDebugger: true),
  );

  group(
    'ServiceConnectionManager',
    () {
      tearDownAll(() async {
        await env.tearDownEnvironment(force: true);
      });

      test('verify number of vm service calls on connect', () async {
        await env.setupEnvironment();
        // Await a delay to ensure the service extensions have had a chance to
        // be called. This delay may be able to be shortened if doing so does
        // not cause bot flakiness.
        await Future.delayed(const Duration(seconds: 10));
        // Ensure all futures are completed before running checks.
        await serviceManager.service!.allFuturesCompleted;
        expect(
          // Use a range instead of an exact number because service extension
          // calls are not consistent. This will still catch any spurious calls
          // that are unintentionally added at start up.
          const Range(15, 35)
              .contains(serviceManager.service!.vmServiceCallCount),
          isTrue,
          reason:
              'Unexpected number of vm service calls upon connection. If this '
              'is expected, please update this test to the new expected number '
              'of calls. Here are the calls for this test run:\n'
              '${serviceManager.service!.vmServiceCalls.toString()}',
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
            'getVersion',
            'callMethod getDartDevelopmentServiceVersion',
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
          equals(8),
        );

        await env.tearDownEnvironment();
      }, timeout: const Timeout.factor(4));

      test('vmServiceOpened', () async {
        await env.setupEnvironment();

        expect(serviceManager.service, equals(env.service));
        expect(serviceManager.isolateManager, isNotNull);
        expect(serviceManager.serviceExtensionManager, isNotNull);
        expect(serviceManager.vmFlagManager, isNotNull);
        expect(serviceManager.isolateManager.isolates.value, isNotEmpty);
        expect(serviceManager.vmFlagManager.flags.value, isNotNull);

        if (serviceManager.isolateManager.selectedIsolate.value == null) {
          await whenValueNonNull(serviceManager.isolateManager.selectedIsolate);
        }

        await env.tearDownEnvironment();
      });

      test('invalid setBreakpoint throws exception', () async {
        await env.setupEnvironment();

        await expectLater(
          serviceManager.service!.addBreakpoint(
              serviceManager.isolateManager.selectedIsolate.value!.id!,
              'fake-script-id',
              1),
          throwsA(const TypeMatcher<RPCError>()
              .having((e) => e.code, 'code', equals(jsonRpcInvalidParamsCode))),
        );

        await env.tearDownEnvironment();
      }, timeout: const Timeout.factor(4));

      test('toggle boolean service extension', () async {
        await env.setupEnvironment();
        await serviceManager.service!.allFuturesCompleted;

        final extensionName = extensions.debugPaint.extension;
        const evalExpression = 'debugPaintSizeEnabled';
        final library = EvalOnDartLibrary(
          'package:flutter/src/rendering/debug.dart',
          env.service!,
        );

        await _serviceExtensionAvailable(extensionName);

        await _verifyExtensionStateOnTestDevice(
            evalExpression, 'false', library);
        await _verifyInitialExtensionStateInServiceManager(extensionName);

        // Enable the service extension via ServiceExtensionManager.
        await serviceManager.serviceExtensionManager.setServiceExtensionState(
          extensionName,
          enabled: true,
          value: true,
        );

        await _verifyExtensionStateOnTestDevice(
            evalExpression, 'true', library);
        await _verifyExtensionStateInServiceManager(extensionName, true, true);

        await env.tearDownEnvironment();
      }, timeout: const Timeout.factor(4));

      test('toggle String service extension', () async {
        await env.setupEnvironment();
        await serviceManager.service!.allFuturesCompleted;

        final extensionName = extensions.togglePlatformMode.extension;
        await _serviceExtensionAvailable(extensionName);
        const evalExpression = 'defaultTargetPlatform.toString()';
        final library = EvalOnDartLibrary(
          'package:flutter/src/foundation/platform.dart',
          env.service!,
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
          enabled: true,
          value: 'iOS',
        );

        await _verifyExtensionStateOnTestDevice(
          evalExpression,
          'TargetPlatform.iOS',
          library,
        );
        await _verifyExtensionStateInServiceManager(extensionName, true, 'iOS');

        await env.tearDownEnvironment();
      }, timeout: const Timeout.factor(4));

      test(
        'toggle numeric service extension',
        () async {
          await env.setupEnvironment();
          await serviceManager.service!.allFuturesCompleted;

          final extensionName = extensions.slowAnimations.extension;
          await _serviceExtensionAvailable(extensionName);
          const evalExpression = 'timeDilation';
          final library = EvalOnDartLibrary(
            'package:flutter/src/scheduler/binding.dart',
            env.service!,
          );

          await _verifyExtensionStateOnTestDevice(
              evalExpression, '1.0', library);
          await _verifyInitialExtensionStateInServiceManager(extensionName);

          // Enable the service extension via ServiceExtensionManager.
          await serviceManager.serviceExtensionManager.setServiceExtensionState(
            extensionName,
            enabled: true,
            value: 5.0,
          );

          await _verifyExtensionStateOnTestDevice(
              evalExpression, '5.0', library);
          await _verifyExtensionStateInServiceManager(extensionName, true, 5.0);

          await env.tearDownEnvironment();
        },
        timeout: const Timeout.factor(4),
      );

      test(
        'callService',
        () async {
          await env.setupEnvironment();

          final registeredService = serviceManager.registeredMethodsForService[
                  registrations.hotReload.service] ??
              const [];
          expect(registeredService, isNotEmpty);

          await serviceManager.callService(
            registrations.hotReload.service,
            isolateId: serviceManager.isolateManager.mainIsolate.value!.id,
          );

          await env.tearDownEnvironment();
        },
        timeout: const Timeout.factor(4),
      );

      test('callService throws exception', () async {
        await env.setupEnvironment();

        // Service with 0 registrations.
        await expectLater(
            serviceManager.callService('fakeMethod'), throwsException);

        await env.tearDownEnvironment();
      }, timeout: const Timeout.factor(4));

      test('hotReload', () async {
        await env.setupEnvironment();

        await serviceManager.performHotReload();

        await env.tearDownEnvironment();
      }, timeout: const Timeout.factor(4));

      // TODO(kenz): once hot restart tests are fixed, add a hot restart test
      // that verifies the state of service extensions after a hot restart.
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

        expect(await serviceManager.queryDisplayRefreshRate, equals(60));

        await env.tearDownEnvironment();
      }, timeout: const Timeout.factor(4));
    },
  );

  group('ServiceConnectionManager - restoring device-enabled extension', () {
    test('all extension types', () async {
      await env.setupEnvironment();

      final service = serviceManager.service!;

      /// Helper method to call an extension on the test device and verify that
      /// the device reflects the new extension state.
      Future<void> _enableExtensionOnTestDevice(
        extensions.ServiceExtensionDescription extensionDescription,
        Map<String, dynamic> args,
        String evalExpression,
        EvalOnDartLibrary library, {
        String? newValue,
        String? oldValue,
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
        await service.callServiceExtension(
          extensionDescription.extension,
          isolateId: serviceManager.isolateManager.mainIsolate.value!.id,
          args: args,
        );

        // Verify extension state after calling the service extension.
        await _verifyExtensionStateOnTestDevice(
          evalExpression,
          newValue,
          library,
        );
      }

      // Enable a boolean extension on the test device.
      final boolExtensionDescription = extensions.debugPaint;
      final boolArgs = {'enabled': true};
      const boolEvalExpression = 'debugPaintSizeEnabled';
      final boolLibrary = EvalOnDartLibrary(
        'package:flutter/src/rendering/debug.dart',
        service,
        isolate: serviceManager.isolateManager.mainIsolate,
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
        'package:flutter/src/foundation/platform.dart',
        service,
        isolate: serviceManager.isolateManager.mainIsolate,
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
        'package:flutter/src/scheduler/binding.dart',
        service,
        isolate: serviceManager.isolateManager.mainIsolate,
      );
      await _enableExtensionOnTestDevice(
        numericExtensionDescription,
        numericArgs,
        numericEvalExpression,
        numericLibrary,
      );

      await _verifyExtensionStateInServiceManager(
        boolExtensionDescription.extension,
        true,
        boolExtensionDescription.enabledValue,
      );
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
      await env.tearDownEnvironment();
    }, timeout: const Timeout.factor(4));
  });
}

// Returns a future that completes when the service extension is available.
Future<void> _serviceExtensionAvailable(String extensionName) async {
  final listenable =
      serviceManager.serviceExtensionManager.hasServiceExtension(extensionName);

  final completer = Completer<void>();
  final listener = () {
    if (listenable.value == true && !completer.isCompleted) {
      completer.complete();
    }
  };
  listener();
  listenable.addListener(listener);
  await completer.future;
  listenable.removeListener(listener);
}

Future<void> _verifyExtensionStateOnTestDevice(
  String evalExpression,
  String? expectedResult,
  EvalOnDartLibrary library,
) async {
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
  final stateListenable = serviceManager.serviceExtensionManager
      .getServiceExtensionState(extensionName);

  // Wait for the service extension state to match the expected value.
  final Completer<ServiceExtensionState> stateCompleter = Completer();
  final stateListener = () {
    if (stateListenable.value.value == value) {
      stateCompleter.complete(stateListenable.value);
    }
  };

  stateListenable.addListener(stateListener);
  stateListener();

  final ServiceExtensionState state = await stateCompleter.future;
  stateListenable.removeListener(stateListener);
  expect(state.enabled, equals(enabled));
  expect(state.value, equals(value));
}
