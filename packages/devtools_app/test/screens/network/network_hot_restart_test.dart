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
  group('Network View hot restart', () {
    late HotRestartNetworkVmService vmService;
    late FakeServiceConnectionManager fakeServiceConnection;

    setUp(() {
      vmService = HotRestartNetworkVmService();
      fakeServiceConnection = FakeServiceConnectionManager(service: vmService);
    });

    tearDown(disposeNetworkLifecycleControllers);

    group('baseline behavior before hot restart', () {
      test('displays HTTP requests after recording starts', () async {
        final controller = await initNetworkLifecycleController(
          vmService: vmService,
          fakeServiceConnection: fakeServiceConnection,
          initialProfile: [
            createTestHttpRequest(id: 'pre-restart-1', method: 'GET'),
          ],
        );

        expect(
          vmService.isHttpLoggingEnabled(vmService.currentIsolateId),
          isTrue,
        );
        await controller.networkService.refreshNetworkData();

        expect(controller.requests.value, hasLength(1));
        expect(
          controller.requests.value.single,
          isA<DartIOHttpRequestData>().having(
            (request) => request.method,
            'method',
            'GET',
          ),
        );
      });

      test('continues polling while connected', () async {
        final controller = await initNetworkLifecycleController(
          vmService: vmService,
          fakeServiceConnection: fakeServiceConnection,
        );
        expect(controller.isPolling, isTrue);
        expect(controller.recordingNotifier.value, isTrue);
      });
    });

    group('hot restart request visibility', () {
      test(
        'continues displaying new HTTP requests after hot restart',
        () async {
          final controller = await initNetworkLifecycleController(
            vmService: vmService,
            fakeServiceConnection: fakeServiceConnection,
            initialProfile: [
              createTestHttpRequest(id: 'pre-restart', method: 'GET'),
            ],
          );
          await controller.networkService.refreshNetworkData();
          expect(controller.requests.value, hasLength(1));

          final postRestartIsolateId = vmService.simulateHotRestart();
          notifyMainIsolateChanged(fakeServiceConnection, postRestartIsolateId);
          await pumpEventQueue();
          vmService.setHttpProfile(postRestartIsolateId, [
            createTestHttpRequest(
              id: 'post-restart',
              method: 'POST',
              startTime: 8_000_000,
            ),
          ]);

          await controller.networkService.refreshNetworkData();

          final methods = controller.requests.value
              .whereType<DartIOHttpRequestData>()
              .map((request) => request.method)
              .toSet();
          expect(
            methods,
            contains('POST'),
            reason:
                'Network View should display requests made on the new isolate '
                'after a hot restart.',
          );
        },
      );

      test('polling remains active after hot restart', () async {
        final controller = await initNetworkLifecycleController(
          vmService: vmService,
          fakeServiceConnection: fakeServiceConnection,
        );
        expect(controller.isPolling, isTrue);

        final postRestartIsolateId = vmService.simulateHotRestart();
        notifyMainIsolateChanged(fakeServiceConnection, postRestartIsolateId);

        expect(controller.isPolling, isTrue);
        expect(controller.recordingNotifier.value, isTrue);
      });
    });

    group('profiling re-registration after hot restart', () {
      test(
        're-enables HTTP timeline logging on the new isolate after hot restart',
        () async {
          final preRestartIsolateId = vmService.currentIsolateId;
          await initNetworkLifecycleController(
            vmService: vmService,
            fakeServiceConnection: fakeServiceConnection,
          );
          expect(vmService.isHttpLoggingEnabled(preRestartIsolateId), isTrue);

          final postRestartIsolateId = vmService.simulateHotRestart();
          notifyMainIsolateChanged(fakeServiceConnection, postRestartIsolateId);
          await pumpEventQueue();

          expect(
            vmService.isHttpLoggingEnabled(postRestartIsolateId),
            isTrue,
            reason:
                'HTTP timeline logging must be re-enabled on the new main '
                'isolate after a hot restart.',
          );
        },
      );

      test(
        're-enables socket profiling on the new isolate after hot restart',
        () async {
          final preRestartIsolateId = vmService.currentIsolateId;
          await initNetworkLifecycleController(
            vmService: vmService,
            fakeServiceConnection: fakeServiceConnection,
          );
          expect(
            vmService.isSocketProfilingEnabled(preRestartIsolateId),
            isTrue,
          );

          final postRestartIsolateId = vmService.simulateHotRestart();
          notifyMainIsolateChanged(fakeServiceConnection, postRestartIsolateId);
          await pumpEventQueue();

          expect(
            vmService.isSocketProfilingEnabled(postRestartIsolateId),
            isTrue,
            reason:
                'Socket profiling must be re-enabled on the new main isolate '
                'after a hot restart.',
          );
        },
      );
    });

    group('isolate refresh timestamp tracking', () {
      test(
        'fetches HTTP profile data for a new isolate after profiling is re-enabled',
        () async {
          final controller = await initNetworkLifecycleController(
            vmService: vmService,
            fakeServiceConnection: fakeServiceConnection,
          );
          await controller.networkService.refreshNetworkData();

          final postRestartIsolateId = vmService.simulateHotRestart();
          notifyMainIsolateChanged(fakeServiceConnection, postRestartIsolateId);
          vmService.setHttpProfile(postRestartIsolateId, [
            createTestHttpRequest(
              id: 'new-isolate-request',
              method: 'PUT',
              startTime: 9_000_000,
            ),
          ]);

          await pumpEventQueue();
          await controller.networkService.refreshNetworkData();

          expect(
            controller.networkService.lastHttpDataRefreshTimePerIsolate
                .containsKey(postRestartIsolateId),
            isTrue,
            reason:
                'NetworkService should track refresh timestamps for the new '
                'isolate after a hot restart.',
          );
          expect(
            controller.requests.value.whereType<DartIOHttpRequestData>().map(
              (request) => request.method,
            ),
            contains('PUT'),
          );
        },
      );

      test(
        'stale isolate IDs do not prevent fetching from the new isolate',
        () async {
          final preRestartIsolateId = vmService.currentIsolateId;
          final controller = await initNetworkLifecycleController(
            vmService: vmService,
            fakeServiceConnection: fakeServiceConnection,
          );
          await controller.networkService.refreshNetworkData();

          controller
                  .networkService
                  .lastHttpDataRefreshTimePerIsolate[preRestartIsolateId] =
              12_000_000;

          final postRestartIsolateId = vmService.simulateHotRestart();
          notifyMainIsolateChanged(fakeServiceConnection, postRestartIsolateId);
          vmService.setHttpProfile(postRestartIsolateId, [
            createTestHttpRequest(
              id: 'after-stale-isolate',
              method: 'DELETE',
              startTime: 10_000_000,
            ),
          ]);
          await pumpEventQueue();
          await controller.networkService.refreshNetworkData();

          expect(
            controller.requests.value.whereType<DartIOHttpRequestData>().map(
              (request) => request.method,
            ),
            contains('DELETE'),
          );
        },
      );
    });

    group('state restoration across hot restart', () {
      test('retains pre-restart requests when not cleared', () async {
        final controller = await initNetworkLifecycleController(
          vmService: vmService,
          fakeServiceConnection: fakeServiceConnection,
          initialProfile: [
            createTestHttpRequest(id: 'kept-request', method: 'GET'),
          ],
        );
        await controller.networkService.refreshNetworkData();
        expect(controller.requests.value, hasLength(1));

        final postRestartIsolateId = vmService.simulateHotRestart();
        notifyMainIsolateChanged(fakeServiceConnection, postRestartIsolateId);
        vmService.setHttpProfile(postRestartIsolateId, [
          createTestHttpRequest(
            id: 'new-request',
            method: 'POST',
            startTime: 11_000_000,
          ),
        ]);
        await pumpEventQueue();
        await controller.networkService.refreshNetworkData();

        final methods = controller.requests.value
            .whereType<DartIOHttpRequestData>()
            .map((request) => request.method)
            .toList();
        expect(methods, contains('GET'));
        expect(methods, contains('POST'));
      });

      test(
        'clears selected request when it is no longer in filtered data',
        () async {
          final controller = await initNetworkLifecycleController(
            vmService: vmService,
            fakeServiceConnection: fakeServiceConnection,
            initialProfile: [
              createTestHttpRequest(id: 'selected-request', method: 'GET'),
            ],
          );
          await controller.networkService.refreshNetworkData();
          controller.selectedRequest.value = controller.requests.value.first;

          await controller.clear();
          expect(controller.selectedRequest.value, isNull);
        },
      );
    });
  });

  group('Network View service lifecycle', () {
    tearDown(disposeNetworkLifecycleControllers);

    test(
      'starts recording when controller initializes while connected',
      () async {
        final reconnectionService = HotRestartNetworkVmService();
        final connection = FakeServiceConnectionManager(
          service: reconnectionService,
        );
        final reconnectedController = await initNetworkLifecycleController(
          vmService: reconnectionService,
          fakeServiceConnection: connection,
        );

        expect(reconnectedController.isPolling, isTrue);
        expect(
          reconnectionService.isHttpLoggingEnabled(
            reconnectionService.currentIsolateId,
          ),
          isTrue,
        );
      },
    );

    test(
      're-initializes recording after controller is disposed and recreated',
      () async {
        final vmService = HotRestartNetworkVmService();
        final connection = FakeServiceConnectionManager(service: vmService);
        final isolateId = vmService.currentIsolateId;
        await initNetworkLifecycleController(
          vmService: vmService,
          fakeServiceConnection: connection,
        );

        screenControllers.disposeConnectedControllers();

        final recreatedController = await initNetworkLifecycleController(
          vmService: vmService,
          fakeServiceConnection: connection,
        );

        expect(recreatedController.isPolling, isTrue);
        expect(vmService.isHttpLoggingEnabled(isolateId), isTrue);
      },
    );
  });

  group('NetworkService hot restart edge cases', () {
    tearDown(disposeNetworkLifecycleControllers);

    test(
      'refreshNetworkData is a no-op when the VM service is unavailable',
      () async {
        final localVmService = HotRestartNetworkVmService();
        final localConnection = FakeServiceConnectionManager(
          service: localVmService,
        );
        final localController = await initNetworkLifecycleController(
          vmService: localVmService,
          fakeServiceConnection: localConnection,
        );

        localConnection.serviceManager.service = null;
        await expectLater(
          localController.networkService.refreshNetworkData(),
          completes,
        );
        expect(localController.requests.value, isEmpty);
      },
    );

    test(
      'updateLastHttpDataRefreshTime does not add entries for new isolates',
      () async {
        final localVmService = HotRestartNetworkVmService();
        final localConnection = FakeServiceConnectionManager(
          service: localVmService,
        );
        final localController = await initNetworkLifecycleController(
          vmService: localVmService,
          fakeServiceConnection: localConnection,
        );

        final postRestartIsolateId = localVmService.simulateHotRestart();
        localController.networkService.updateLastHttpDataRefreshTime();

        expect(
          localController.networkService.lastHttpDataRefreshTimePerIsolate
              .containsKey(postRestartIsolateId),
          isFalse,
          reason:
              'updateLastHttpDataRefreshTime only updates existing isolate '
              'entries; new isolates are registered on the first profile fetch.',
        );
      },
    );
  });
}
