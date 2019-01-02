@TestOn('vm')
import 'dart:async';
import 'dart:io';

import 'package:devtools/eval_on_dart_library.dart';
import 'package:devtools/globals.dart';
import 'package:devtools/service_manager.dart';
import 'package:devtools/vm_service_wrapper.dart';
import 'package:test/test.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import 'flutter_test_driver.dart';

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
