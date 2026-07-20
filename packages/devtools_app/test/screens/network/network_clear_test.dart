// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('vm')
library;

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utils/hot_restart_network_vm_service.dart';
import 'utils/network_lifecycle_test_utils.dart';
import 'utils/network_test_utils.dart';

void main() {
  group('Network View clear button', () {
    late HotRestartNetworkVmService vmService;
    late FakeServiceConnectionManager fakeServiceConnection;

    setUp(() {
      vmService = HotRestartNetworkVmService();
      fakeServiceConnection = FakeServiceConnectionManager(service: vmService);
    });

    tearDown(disposeNetworkLifecycleControllers);

    group('request visibility after clear', () {
      test('displays new HTTP requests after clear while recording', () async {
        final isolateId = vmService.currentIsolateId;
        final controller = await initNetworkLifecycleController(
          vmService: vmService,
          fakeServiceConnection: fakeServiceConnection,
          initialProfile: [
            createTestHttpRequest(id: 'before-clear', method: 'GET'),
          ],
        );
        await controller.networkService.refreshNetworkData();
        expect(controller.requests.value, hasLength(1));

        await controller.clear();
        expect(controller.requests.value, isEmpty);

        vmService.appendHttpRequest(
          isolateId,
          createTestHttpRequest(id: 'after-clear', method: 'POST'),
        );
        await controller.networkService.refreshNetworkData();

        expect(
          controller.requests.value.whereType<DartIOHttpRequestData>().map(
            (request) => request.method,
          ),
          contains('POST'),
          reason:
              'Network View should display new requests after Clear while '
              'recording is active.',
        );
      });

      test('polling remains active after clear', () async {
        final controller = await initNetworkLifecycleController(
          vmService: vmService,
          fakeServiceConnection: fakeServiceConnection,
          initialProfile: [
            createTestHttpRequest(id: 'polling-test', method: 'GET'),
          ],
        );
        await controller.networkService.refreshNetworkData();

        await controller.clear();

        expect(controller.isPolling, isTrue);
        expect(controller.recordingNotifier.value, isTrue);
      });

      test('keeps HTTP logging enabled after clear', () async {
        final isolateId = vmService.currentIsolateId;
        final controller = await initNetworkLifecycleController(
          vmService: vmService,
          fakeServiceConnection: fakeServiceConnection,
          initialProfile: [
            createTestHttpRequest(id: 'logging-test', method: 'GET'),
          ],
        );
        await controller.networkService.refreshNetworkData();

        await controller.clear();

        expect(vmService.isHttpLoggingEnabled(isolateId), isTrue);
      });

      test('keeps socket profiling enabled after clear', () async {
        final isolateId = vmService.currentIsolateId;
        final controller = await initNetworkLifecycleController(
          vmService: vmService,
          fakeServiceConnection: fakeServiceConnection,
          initialProfile: [
            createTestHttpRequest(id: 'socket-test', method: 'GET'),
          ],
        );
        await controller.networkService.refreshNetworkData();

        await controller.clear();

        expect(vmService.isSocketProfilingEnabled(isolateId), isTrue);
      });
    });

    group('clear refresh timestamp tracking', () {
      test(
        'resets HTTP refresh timestamps to the VM timeline on clear',
        () async {
          final isolateId = vmService.currentIsolateId;
          final controller = await initNetworkLifecycleController(
            vmService: vmService,
            fakeServiceConnection: fakeServiceConnection,
          );
          await controller.networkService.refreshNetworkData();

          controller
                  .networkService
                  .lastHttpDataRefreshTimePerIsolate[isolateId] =
              500_000;

          await controller.clear();

          final timelineMicros =
              (await vmService.getVMTimelineMicros()).timestamp!;
          expect(
            controller
                .networkService
                .lastHttpDataRefreshTimePerIsolate[isolateId],
            timelineMicros,
          );
        },
      );

      test('does not show stale requests after clear', () async {
        final controller = await initNetworkLifecycleController(
          vmService: vmService,
          fakeServiceConnection: fakeServiceConnection,
          initialProfile: [
            createTestHttpRequest(
              id: 'stale-request',
              method: 'GET',
              startTime: 1_500_000,
            ),
          ],
        );
        await controller.networkService.refreshNetworkData();
        expect(controller.requests.value, hasLength(1));

        await controller.clear();
        await controller.networkService.refreshNetworkData();

        expect(controller.requests.value, isEmpty);
      });
    });

    group('clear combined with hot restart', () {
      test('clear then hot restart then new requests', () async {
        final controller = await initNetworkLifecycleController(
          vmService: vmService,
          fakeServiceConnection: fakeServiceConnection,
          initialProfile: [
            createTestHttpRequest(id: 'pre-clear', method: 'GET'),
          ],
        );
        await controller.networkService.refreshNetworkData();
        await controller.clear();

        final postRestartIsolateId = vmService.simulateHotRestart();
        notifyMainIsolateChanged(fakeServiceConnection, postRestartIsolateId);
        await pumpEventQueue();

        vmService.appendHttpRequest(
          postRestartIsolateId,
          createTestHttpRequest(
            id: 'after-clear-and-restart',
            method: 'PUT',
            startTime: 9_000_000,
          ),
        );
        await controller.networkService.refreshNetworkData();

        expect(
          controller.requests.value.whereType<DartIOHttpRequestData>().map(
            (request) => request.method,
          ),
          contains('PUT'),
        );
        expect(vmService.isHttpLoggingEnabled(postRestartIsolateId), isTrue);
      });

      test('hot restart then clear then new requests', () async {
        final controller = await initNetworkLifecycleController(
          vmService: vmService,
          fakeServiceConnection: fakeServiceConnection,
          initialProfile: [
            createTestHttpRequest(id: 'pre-restart', method: 'GET'),
          ],
        );
        await controller.networkService.refreshNetworkData();

        final postRestartIsolateId = vmService.simulateHotRestart();
        notifyMainIsolateChanged(fakeServiceConnection, postRestartIsolateId);
        await pumpEventQueue();
        vmService.appendHttpRequest(
          postRestartIsolateId,
          createTestHttpRequest(
            id: 'after-restart',
            method: 'POST',
            startTime: 8_000_000,
          ),
        );
        await controller.networkService.refreshNetworkData();
        expect(controller.requests.value, isNotEmpty);

        await controller.clear();
        expect(controller.requests.value, isEmpty);

        vmService.appendHttpRequest(
          postRestartIsolateId,
          createTestHttpRequest(
            id: 'after-restart-and-clear',
            method: 'DELETE',
            startTime: 10_000_000,
          ),
        );
        await controller.networkService.refreshNetworkData();

        expect(
          controller.requests.value.whereType<DartIOHttpRequestData>().map(
            (request) => request.method,
          ),
          contains('DELETE'),
        );
      });
    });

    group('state after clear', () {
      test('clears selected request', () async {
        final controller = await initNetworkLifecycleController(
          vmService: vmService,
          fakeServiceConnection: fakeServiceConnection,
          initialProfile: [
            createTestHttpRequest(id: 'selected', method: 'GET'),
          ],
        );
        await controller.networkService.refreshNetworkData();
        controller.selectedRequest.value = controller.requests.value.first;

        await controller.clear();

        expect(controller.selectedRequest.value, isNull);
      });

      test('preserves active search text', () async {
        final controller = await initNetworkLifecycleController(
          vmService: vmService,
          fakeServiceConnection: fakeServiceConnection,
          initialProfile: [
            createTestHttpRequest(
              id: 'searchable',
              method: 'GET',
              uri: 'https://example.com/api',
            ),
          ],
        );
        await controller.networkService.refreshNetworkData();
        controller.search = 'example';

        await controller.clear();

        expect(controller.search, 'example');
      });

      test('supports multiple consecutive clears', () async {
        final isolateId = vmService.currentIsolateId;
        final controller = await initNetworkLifecycleController(
          vmService: vmService,
          fakeServiceConnection: fakeServiceConnection,
          initialProfile: [
            createTestHttpRequest(id: 'multi-clear-1', method: 'GET'),
          ],
        );
        await controller.networkService.refreshNetworkData();

        await controller.clear();
        await controller.clear();

        vmService.appendHttpRequest(
          isolateId,
          createTestHttpRequest(
            id: 'after-multi-clear',
            method: 'PATCH',
            startTime: 3_000_000,
          ),
        );
        await controller.networkService.refreshNetworkData();

        expect(
          controller.requests.value.whereType<DartIOHttpRequestData>().map(
            (request) => request.method,
          ),
          contains('PATCH'),
        );
      });
    });
  });
}
