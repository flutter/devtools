// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:async';
import 'dart:io';

import 'package:devtools/eval_on_dart_library.dart';
import 'package:devtools/globals.dart';
import 'package:devtools/service_manager.dart';
import 'package:devtools/vm_service_wrapper.dart';
import 'package:test/test.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import 'support/flutter_test_driver.dart';

void main() {
  group('serviceManagerTests', () {
    FlutterRunTestDriver _flutter;
    VmServiceWrapper service;

    setUp(() async {
      _flutter =
          FlutterRunTestDriver(new Directory('test/fixtures/flutter_app'));

      await _flutter.run(withDebugger: true);
      service = _flutter.vmService;

      setGlobal(ServiceConnectionManager, new ServiceConnectionManager());

      await serviceManager.vmServiceOpened(service, new Completer().future);
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
      const extensionName = 'ext.flutter.debugPaint';
      const evalExpression = 'debugPaintSizeEnabled';
      final library = new EvalOnDartLibrary(
        'package:flutter/src/rendering/debug.dart',
        service,
      );

      await _verifyExtensionStateOnTestDevice(evalExpression, 'false', library);
      await _verifyInitialExtensionStateInServiceManager(extensionName);

      // Enable the service extension via ServiceExtensionManager.
      await serviceManager.serviceExtensionManager
          .setServiceExtensionState('ext.flutter.debugPaint', true, true);

      await _verifyExtensionStateOnTestDevice(evalExpression, 'true', library);
      await _verifyExtensionStateInServiceManager(extensionName, true, true);
    });

    test('toggle String service extension', () async {
      const extensionName = 'ext.flutter.platformOverride';
      const evalExpression = 'defaultTargetPlatform.toString()';
      final library = new EvalOnDartLibrary(
        'package:flutter/src/foundation/platform.dart',
        service,
      );

      await _verifyExtensionStateOnTestDevice(
          evalExpression, 'TargetPlatform.android', library);
      await _verifyInitialExtensionStateInServiceManager(extensionName);

      // Enable the service extension via ServiceExtensionManager.
      await serviceManager.serviceExtensionManager.setServiceExtensionState(
          'ext.flutter.platformOverride', true, 'iOS');

      await _verifyExtensionStateOnTestDevice(
          evalExpression, 'TargetPlatform.iOS', library);
      await _verifyExtensionStateInServiceManager(extensionName, true, 'iOS');
    });

    test('toggle numeric service extension', () async {
      const extensionName = 'ext.flutter.timeDilation';
      const evalExpression = 'timeDilation';
      final library = new EvalOnDartLibrary(
        'package:flutter/src/scheduler/binding.dart',
        service,
      );

      await _verifyExtensionStateOnTestDevice(evalExpression, '1.0', library);
      await _verifyInitialExtensionStateInServiceManager(extensionName);

      // Enable the service extension via ServiceExtensionManager.
      await serviceManager.serviceExtensionManager
          .setServiceExtensionState(extensionName, true, 0.5);

      await _verifyExtensionStateOnTestDevice(evalExpression, '0.5', library);
      await _verifyExtensionStateInServiceManager(extensionName, true, 0.5);
    });

    test('callService', () async {
      dynamic _e;

      final registeredService =
          serviceManager.methodsForService['reloadSources'] ?? const [];
      expect(registeredService, isNotEmpty);

      try {
        await serviceManager.callService('reloadSources',
            isolateId: serviceManager.isolateManager.selectedIsolate.id);
      } catch (e) {
        _e = e;
      }

      expect(_e, isNull);
    });

    test('callService throws exception', () async {
      // Service with less than 1 registration.
      Exception exception;
      Exception expectedException =
          Exception('Expected one registered service for fakeMethod'
              ' but found 0');

      try {
        await serviceManager.callService('fakeMethod');
      } catch (e) {
        exception = e;
      }

      expect(exception, isNotNull);
      expect(exception.toString(), equals(expectedException.toString()));

      // Service with more than 1 registration.
      serviceManager.methodsForService.putIfAbsent('fakeMethod',
          () => ['registration1.fakeMethod', 'registration2.fakeMethod']);
      exception = null;
      expectedException =
          Exception('Expected one registered service for fakeMethod'
              ' but found 2');

      try {
        await serviceManager.callService('fakeMethod');
      } catch (e) {
        exception = e;
      }

      expect(exception, isNotNull);
      expect(exception.toString(), equals(expectedException.toString()));
    });

    test('callMulticastService', () async {
      dynamic _e;

      final registeredService =
          serviceManager.methodsForService['reloadSources'] ?? const [];
      expect(registeredService, isNotEmpty);

      try {
        await serviceManager.callMulticastService('reloadSources',
            isolateId: serviceManager.isolateManager.selectedIsolate.id);
      } catch (e) {
        _e = e;
      }

      expect(_e, isNull);
    });

    test('callMulticastService throws exception', () async {
      Exception exception;
      final Exception expectedException =
          Exception('There are no registered methods for service fakeMethod');

      try {
        await serviceManager.callMulticastService('fakeMethod');
      } catch (e) {
        exception = e;
      }

      expect(exception, isNotNull);
      expect(exception.toString(), equals(expectedException.toString()));
    });

    test('hotReload', () async {
      dynamic _e;

      try {
        await serviceManager.performHotReload();
      } catch (e) {
        _e = e;
      }

      expect(_e, isNull);
    });

    // TODO(kenzie): add hot restart test case.
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

  final Completer<ServiceExtensionState> stateCompleter = new Completer();
  stream.onData((ServiceExtensionState state) {
    stateCompleter.complete(state);
    stream.cancel();
  });

  final ServiceExtensionState state = await stateCompleter.future;
  expect(state.enabled, equals(enabled));
  expect(state.value, equals(value));
}
