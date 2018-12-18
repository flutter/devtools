import 'dart:async';
import 'package:devtools/eval_on_dart_library.dart';
import 'package:devtools/globals.dart';
import 'package:devtools/service_manager.dart';
import 'package:devtools/vm_service_wrapper.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:test/test.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import 'test_driver.dart';

void main() {
  group('serviceManagerTests', () {
    FlutterRunTestDriver _flutter;
    VmServiceWrapper service;

    setUp(() async {
      _flutter =
          FlutterRunTestDriver(fs.directory('test/fixtures/flutter_app'));

      await _flutter.run(withDebugger: true);
      service = _flutter.vmService;

      setGlobal(ServiceConnectionManager, new ServiceConnectionManager());

      final completer = new Completer<Null>();
      await serviceManager.vmServiceOpened(service, completer.future);
    });

    tearDown(() async {
      await service.allFuturesCompleted.future;
      _flutter.stop();
    });

    test('vmServiceOpened', () async {
      expect(serviceManager.service, equals(service));
      expect(serviceManager.isolateManager, isNotNull);
      expect(serviceManager.serviceExtensionManager, isNotNull);
      expect(serviceManager.isolateManager.isolates, isNotEmpty);

      // Test should time out and fail if the following await statements do not
      // finish with a value.
      if (serviceManager.isolateManager.selectedIsolate == null) {
        await serviceManager.isolateManager.onSelectedIsolateChanged
            .firstWhere((ref) => ref != null);
      }
      if (serviceManager.isolateManager.flutterIsolate == null) {
        await serviceManager.isolateManager.onFlutterIsolateChanged
            .firstWhere((ref) => ref != null);
      }
    });

    test('toggle boolean service extension', () async {
      final EvalOnDartLibrary library = new EvalOnDartLibrary(
        'package:flutter/src/rendering/debug.dart',
        service,
      );

      StreamSubscription<ServiceExtensionState> stream;

      // Initial value on the test device should be false.
      final before = await library.eval('debugPaintSizeEnabled', isAlive: null);
      if (before is InstanceRef) {
        expect(before.valueAsString, 'false');
      }
      // Initial state in ServiceExtensionManager should be disabled with value
      // null.
      stream = serviceManager.serviceExtensionManager
          .getServiceExtensionState('ext.flutter.debugPaint', null);
      stream.onData((ServiceExtensionState state) {
        expect(state.enabled, false);
        expect(state.value, null);
        stream.cancel();
      });

      // Enable the service extension via ServiceExtensionManager.
      await serviceManager.serviceExtensionManager
          .setServiceExtensionState('ext.flutter.debugPaint', true, true);

      // Verify the test device is aware of the newly-enabled state.
      final after = await library.eval('debugPaintSizeEnabled', isAlive: null);
      if (after is InstanceRef) {
        expect(after.valueAsString, 'true');
      }
      // Verify ServiceExtensionManager is aware of the newly-enabled state.
      stream = serviceManager.serviceExtensionManager
          .getServiceExtensionState('ext.flutter.debugPaint', null);
      stream.onData((ServiceExtensionState state) {
        expect(state.enabled, true);
        expect(state.value, true);
        stream.cancel();
      });
    });

    test('toggle String service extension', () async {
      final EvalOnDartLibrary library = new EvalOnDartLibrary(
        'package:flutter/src/foundation/platform.dart',
        service,
      );

      StreamSubscription<ServiceExtensionState> stream;

      // Initial value on the test device should be TargetPlatform.android.
      final before =
          await library.eval('defaultTargetPlatform.toString()', isAlive: null);
      if (before is InstanceRef) {
        expect(before.valueAsString, 'TargetPlatform.android');
      }
      // Initial state in ServiceExtensionManager should be disabled with value
      // null.
      stream = serviceManager.serviceExtensionManager
          .getServiceExtensionState('ext.flutter.platformOverride', null);
      stream.onData((ServiceExtensionState state) {
        expect(state.enabled, false);
        expect(state.value, null);
        stream.cancel();
      });

      // Enable the service extension via ServiceExtensionManager.
      await serviceManager.serviceExtensionManager.setServiceExtensionState(
          'ext.flutter.platformOverride', true, 'iOS');

      // Verify the test device is aware of the newly-enabled state.
      final after =
          await library.eval('defaultTargetPlatform.toString()', isAlive: null);
      if (after is InstanceRef) {
        expect(after.valueAsString, 'TargetPlatform.iOS');
      }
      // Verify ServiceExtensionManager is aware of the newly-enabled state.
      stream = serviceManager.serviceExtensionManager
          .getServiceExtensionState('ext.flutter.platformOverride', null);
      stream.onData((ServiceExtensionState state) {
        expect(state.enabled, true);
        expect(state.value, 'iOS');
        stream.cancel();
      });
    });

    test('toggle numeric service extension', () async {
      final EvalOnDartLibrary library = new EvalOnDartLibrary(
        'package:flutter/src/scheduler/binding.dart',
        service,
      );

      StreamSubscription<ServiceExtensionState> stream;

      // Initial value on the test device should be 1.0.
      final before = await library.eval('timeDilation', isAlive: null);
      if (before is InstanceRef) {
        expect(before.valueAsString, '1.0');
      }
      // Initial state in ServiceExtensionManager should be disabled with value
      // null.
      stream = serviceManager.serviceExtensionManager
          .getServiceExtensionState('ext.flutter.timeDilation', null);
      stream.onData((ServiceExtensionState state) {
        expect(state.enabled, false);
        expect(state.value, null);
        stream.cancel();
      });

      // Enable the service extension via ServiceExtensionManager.
      await serviceManager.serviceExtensionManager
          .setServiceExtensionState('ext.flutter.timeDilation', true, 0.5);

      // Verify the test device is aware of the newly-enabled state.
      final after = await library.eval('timeDilation', isAlive: null);
      if (after is InstanceRef) {
        expect(after.valueAsString, '0.5');
      }
      // Verify ServiceExtensionManager is aware of the newly-enabled state.
      stream = serviceManager.serviceExtensionManager
          .getServiceExtensionState('ext.flutter.timeDilation', null);
      stream.onData((ServiceExtensionState state) {
        expect(state.enabled, true);
        expect(state.value, 0.5);
        stream.cancel();
      });
    });

    //TODO(kenzie): add hot restart test case
  });
}
