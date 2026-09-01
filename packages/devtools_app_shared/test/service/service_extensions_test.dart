// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/service_extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  group('ServiceExtensions', () {
    test('brightnessMode is properly configured', () {
      expect(
        brightnessMode.extension,
        equals('ext.flutter.brightnessOverride'),
      );
      expect(
        brightnessMode.values,
        equals(['system', 'Brightness.light', 'Brightness.dark']),
      );
      expect(
        serviceExtensionsAllowlist[brightnessMode.extension],
        equals(brightnessMode),
      );
    });

    test('brightnessMode is in unsafe before first frame set', () {
      expect(
        isUnsafeBeforeFirstFlutterFrame('ext.flutter.brightnessOverride'),
        isTrue,
      );
    });

    test(
      'ServiceExtensionManager handles RPCError / DWDS Promise collected gracefully',
      () async {
        var extensionCalls = 0;
        final fakeService = _FakeVmService(
          onCallServiceExtension: (method, isolateId, args) {
            extensionCalls++;
            throw RPCError(
              'callServiceExtension',
              -32603,
              'Unexpected DWDS error for callServiceExtension: WipError\n-32000 Promise was collected',
            );
          },
        );

        final isolateManager = IsolateManager();
        isolateManager.vmServiceOpened(fakeService);

        final manager = ServiceExtensionManager(isolateManager);
        manager.vmServiceOpened(fakeService, _FakeConnectedApp());

        // Pre-enable an extension (like ErrorBadgeManager does for structuredErrors).
        await manager.setServiceExtensionState(
          structuredErrors.extension,
          enabled: true,
          value: true,
          callExtension: false,
        );

        // Initialize isolates on IsolateManager.
        final isolateRef = IsolateRef(
          id: 'isolate-1',
          number: '1',
          name: 'main',
        );
        await isolateManager.init([isolateRef]);

        // Wait for all async listeners and microtasks to complete.
        await pumpEventQueue();

        // Verify that the manager attempted to restore the pre-enabled extension
        // state on the newly registered isolate (and gracefully handled the error).
        expect(extensionCalls, equals(1));
      },
    );
  });
}

/// A fake [VmService] implementation for testing service extension calls.
class _FakeVmService extends Fake implements VmService {
  _FakeVmService({required this.onCallServiceExtension});

  final Future<Response> Function(
    String method,
    String? isolateId,
    Map<String, dynamic>? args,
  )
  onCallServiceExtension;

  @override
  Stream<Event> get onIsolateEvent => const Stream<Event>.empty();

  @override
  Stream<Event> get onExtensionEvent => const Stream<Event>.empty();

  @override
  Stream<Event> get onDebugEvent => const Stream<Event>.empty();

  @override
  Future<Isolate> getIsolate(String isolateId) async => Isolate(
    id: isolateId,
    number: '1',
    name: 'main',
    extensionRPCs: [structuredErrors.extension],
  );

  @override
  Future<Response> callServiceExtension(
    String method, {
    String? isolateId,
    Map<String, dynamic>? args,
  }) {
    return onCallServiceExtension(method, isolateId, args);
  }
}

/// A fake [ConnectedApp] implementation that simulates a connected Flutter app.
class _FakeConnectedApp extends Fake implements ConnectedApp {
  @override
  Future<bool> get isFlutterApp async => true;
}
