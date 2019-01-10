// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:async';
import 'dart:io';

import 'package:devtools/eval_on_dart_library.dart';
import 'package:devtools/globals.dart';
import 'package:devtools/service_extensions.dart' as extensions;
import 'package:devtools/service_manager.dart';
import 'package:devtools/service_registrations.dart' as registrations;
import 'package:devtools/vm_service_wrapper.dart';
import 'package:test/test.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import 'support/flutter_test_driver.dart';

void main() {
  group('serviceManagerTests', () {
    FlutterRunTestDriver _flutter;
    VmServiceWrapper service;

    setUp(() async {
      _flutter = FlutterRunTestDriver(Directory('test/fixtures/flutter_app'));

      await _flutter.run(withDebugger: true);
      service = _flutter.vmService;

      setGlobal(ServiceConnectionManager, ServiceConnectionManager());

      await serviceManager.vmServiceOpened(service, Completer().future);
    });

    tearDown(() async {
      await service.allFuturesCompleted.future;
      await _flutter.stop();
    });

    test('vmServiceOpened', () async {
      expect(serviceManager.service, equals(service));
      expect(serviceManager.isolateManager, isNotNull);
      expect(serviceManager.serviceExtensionManager, isNotNull);
      expect(serviceManager.isolateManager.isolates, isNotEmpty);

      if (serviceManager.isolateManager.selectedIsolate == null) {
        await serviceManager.isolateManager.onSelectedIsolateChanged
            .firstWhere((ref) => ref != null);
      }
    });

    test('toggle boolean service extension', () async {
      final extensionName = extensions.debugPaint.extension;
      const evalExpression = 'debugPaintSizeEnabled';
      final library = EvalOnDartLibrary(
        'package:flutter/src/rendering/debug.dart',
        service,
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
    });

    test('toggle String service extension', () async {
      final extensionName = extensions.togglePlatformMode.extension;
      const evalExpression = 'defaultTargetPlatform.toString()';
      final library = EvalOnDartLibrary(
        'package:flutter/src/foundation/platform.dart',
        service,
      );

      await _verifyExtensionStateOnTestDevice(
        evalExpression,
        'TargetPlatform.android',
        library,
      );
      await _verifyInitialExtensionStateInServiceManager(extensionName);

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
    });

    test('toggle numeric service extension', () async {
      final extensionName = extensions.slowAnimations.extension;
      const evalExpression = 'timeDilation';
      final library = EvalOnDartLibrary(
        'package:flutter/src/scheduler/binding.dart',
        service,
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
    });

    test('callService', () async {
      final registeredService = serviceManager
              .registeredMethodsForService[registrations.reloadSources] ??
          const [];
      expect(registeredService, isNotEmpty);

      await serviceManager.callService(
        registrations.reloadSources,
        isolateId: serviceManager.isolateManager.selectedIsolate.id,
      );
    });

    test('callService throws exception', () async {
      // Service with less than 1 registration.
      expect(serviceManager.callService('fakeMethod'), throwsException);

      // Service with more than 1 registration.
      serviceManager.registeredMethodsForService.putIfAbsent('fakeMethod',
          () => ['registration1.fakeMethod', 'registration2.fakeMethod']);
      expect(serviceManager.callService('fakeMethod'), throwsException);
    });

    test('callMulticastService', () async {
      final registeredService = serviceManager
              .registeredMethodsForService[registrations.reloadSources] ??
          const [];
      expect(registeredService, isNotEmpty);

      await serviceManager.callMulticastService(
        registrations.reloadSources,
        isolateId: serviceManager.isolateManager.selectedIsolate.id,
      );
    });

    test('callMulticastService throws exception', () async {
      expect(serviceManager.callService('fakeMethod'), throwsException);
    });

    test('hotReload', () async {
      await serviceManager.performHotReload();
    });

    // TODO(kenzie): add hot restart test case.
  }, tags: 'useFlutterSdk');

  group('serviceManagerTests - restoring device-enabled extension:', () {
    FlutterRunTestDriver _flutter;
    String _flutterIsolateId;
    VmServiceWrapper service;

    setUp(() async {
      setGlobal(ServiceConnectionManager, new ServiceConnectionManager());

      _flutter =
          FlutterRunTestDriver(new Directory('test/fixtures/flutter_app'));
      await _flutter.run(withDebugger: true);
      _flutterIsolateId = await _flutter.getFlutterIsolateId();

      service = _flutter.vmService;
    });

    tearDown(() async {
      await service.allFuturesCompleted.future;
      await _flutter.stop();
    });

    /// Helper method to call an extension on the test device and verify that
    /// the device reflects the new extension state.
    Future<void> _enableExtensionOnTestDevice(
      extensions.ToggleableServiceExtensionDescription extensionDescription,
      Map<String, dynamic> args,
      String evalExpression,
      EvalOnDartLibrary library, {
      String enabledValue,
      String disabledValue,
    }) async {
      enabledValue ??= extensionDescription.enabledValue.toString();
      disabledValue ??= extensionDescription.disabledValue.toString();

      // Verify initial extension state on test device.
      await _verifyExtensionStateOnTestDevice(
        evalExpression,
        disabledValue,
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
        enabledValue,
        library,
      );
    }

    /// Helper method to enable an extension on the test device, open the
    /// vmService, and verify the enabled extension state is reflected by
    /// [ServiceExtensionManager].
    Future<void> _enableExtensionAndOpenVmService(
      extensions.ToggleableServiceExtensionDescription extensionDescription,
      Map<String, dynamic> args,
      String evalExpression,
      EvalOnDartLibrary library, {
      String enabledValue,
      String disabledValue,
    }) async {
      await _enableExtensionOnTestDevice(
        extensionDescription,
        args,
        evalExpression,
        library,
        enabledValue: enabledValue,
        disabledValue: disabledValue,
      );

      await serviceManager.vmServiceOpened(service, new Completer().future);

      await serviceManager
          .serviceExtensionManager.extensionStatesUpdated.future;

      await _verifyExtensionStateInServiceManager(
        extensionDescription.extension,
        true,
        extensionDescription.enabledValue,
      );
    }

    test('bool extension', () async {
      final extensionDescription = extensions.debugPaint;
      final args = {'enabled': true};
      const evalExpression = 'debugPaintSizeEnabled';
      final library = new EvalOnDartLibrary(
        'package:flutter/src/rendering/debug.dart',
        service,
        isolateId: _flutterIsolateId,
      );

      await _enableExtensionAndOpenVmService(
        extensionDescription,
        args,
        evalExpression,
        library,
      );
    });

    test('String extension', () async {
      final extensionDescription = extensions.togglePlatformMode;
      final args = {'value': 'iOS'};
      const evalExpression = 'defaultTargetPlatform.toString()';
      final library = new EvalOnDartLibrary(
        'package:flutter/src/foundation/platform.dart',
        service,
        isolateId: _flutterIsolateId,
      );

      await _enableExtensionAndOpenVmService(
        extensionDescription,
        args,
        evalExpression,
        library,
        enabledValue: 'TargetPlatform.iOS',
        disabledValue: 'TargetPlatform.android',
      );
    });

    test('numeric extension', () async {
      final extensionDescription = extensions.slowAnimations;
      final args = {
        extensionDescription.extension
                .substring(extensionDescription.extension.lastIndexOf('.') + 1):
            extensionDescription.enabledValue
      };
      const evalExpression = 'timeDilation';
      final library = new EvalOnDartLibrary(
        'package:flutter/src/scheduler/binding.dart',
        service,
        isolateId: _flutterIsolateId,
      );

      await _enableExtensionAndOpenVmService(
        extensionDescription,
        args,
        evalExpression,
        library,
      );
    });
  }, tags: 'useFlutterSdk');
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
