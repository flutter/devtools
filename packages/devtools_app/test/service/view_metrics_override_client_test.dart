// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/service/view_metrics_override_client.dart';
import 'package:devtools_app_shared/service.dart' show FlutterEvent;
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import '../test_infra/utils/view_metrics_override_utils.dart';

void main() {
  group('ViewMetricsOverrideClient', () {
    late ViewMetricsOverrideServiceConnection connection;
    late FakeViewMetricsOverrideExtension extension;
    late ViewMetricsOverrideClient client;

    void emitExtensionEvent(Event event) {
      (connection.serviceManager.service as FakeVmServiceWrapper)
          .emitExtensionEvent(event);
    }

    Event stateChangedEvent({
      required String extensionName,
      required Object? value,
      IsolateRef? isolate,
    }) {
      return Event(
        kind: EventKind.kExtension,
        extensionKind: FlutterEvent.serviceExtensionStateChanged,
        extensionData: ExtensionData.parse({
          'extension': extensionName,
          'value': value,
        }),
        isolate:
            isolate ??
            connection.serviceManager.isolateManager.mainIsolate.value,
        timestamp: 0,
      );
    }

    final callFailure = RPCError(
      viewMetricsOverride,
      RPCErrorKind.kServerError.code,
      'Failed',
    );

    setUp(() {
      connection = ViewMetricsOverrideServiceConnection();
      extension = connection.extension;
      setGlobal(ServiceConnectionManager, connection);
      client = ViewMetricsOverrideClient();
    });

    tearDown(() {
      client.dispose();
    });

    test('is not available until the extension is registered', () async {
      expect(client.available.value, isFalse);

      await client.updateOverrides({'boldText': true});

      expect(extension.calls, isEmpty);
    });

    test('reads the registry once the extension is registered', () async {
      extension.registry['0'] = {'platformBrightness': 'dark'};
      extension.registry['1'] = {'boldText': true};

      await extension.register();
      await pumpEventQueue();

      expect(client.available.value, isTrue);
      expect(extension.calls, [<String, String>{}]);
      expect(client.overrides.value, {'platformBrightness': 'dark'});

      // A client created once the extension is registered reads it too.
      client.dispose();
      client = ViewMetricsOverrideClient();
      await pumpEventQueue();
      expect(client.available.value, isTrue);
      expect(client.overrides.value, {'platformBrightness': 'dark'});
    });

    test('updateOverrides keeps the metrics that other clients set', () async {
      extension.registry['0'] = {
        'platformBrightness': 'dark',
        'boldText': true,
      };
      await extension.register();
      await pumpEventQueue();

      await client.updateOverrides({'highContrast': true, 'boldText': null});

      expect(extension.registry, {
        '0': {'platformBrightness': 'dark', 'highContrast': true},
      });
      expect(client.overrides.value, {
        'platformBrightness': 'dark',
        'highContrast': true,
      });
    });

    test('follows the changes that other clients make', () async {
      await extension.register();
      await pumpEventQueue();
      var notifications = 0;
      client.overrides.addListener(() => notifications++);

      extension.callFromOtherClient({
        'viewId': '0',
        'overrides': jsonEncode({
          'textScaling': [
            [1, 2],
          ],
        }),
      });
      await pumpEventQueue();
      expect(client.overrides.value, {
        'textScaling': [
          [1, 2],
        ],
      });
      expect(notifications, 1);

      // A change to another view does not change the overrides of view 0.
      extension.callFromOtherClient({
        'viewId': '1',
        'overrides': jsonEncode({'boldText': true}),
      });
      await pumpEventQueue();
      expect(notifications, 1);

      // A write starts from the latest event, without reading first.
      await client.updateOverrides({'boldText': true});
      expect(extension.calls, [
        <String, String>{},
        {'viewId': '0', 'overrides': anything},
      ]);
      expect(extension.registry['0'], {
        'textScaling': [
          [1, 2],
        ],
        'boldText': true,
      });
    });

    test('ignores events of other extensions and of other isolates', () async {
      extension.registry['0'] = {'boldText': true};
      await extension.register();
      await pumpEventQueue();

      emitExtensionEvent(
        stateChangedEvent(
          extensionName: 'ext.flutter.brightnessOverride',
          value: <String, Object?>{},
        ),
      );
      emitExtensionEvent(
        stateChangedEvent(
          extensionName: viewMetricsOverride,
          value: <String, Object?>{},
          isolate: IsolateRef(id: 'exited_isolate'),
        ),
      );
      await pumpEventQueue();

      expect(client.overrides.value, {'boldText': true});
    });

    test('a failed call keeps the overrides', () async {
      await extension.register();
      await pumpEventQueue();
      await client.updateOverrides({'boldText': true});

      extension.nextCallError = callFailure;
      await client.updateOverrides({'highContrast': true});

      expect(extension.registry, {
        '0': {'boldText': true},
      });
      expect(client.overrides.value, {'boldText': true});
    });

    test(
      'a write reads the registry first if the app has not reported it',
      () async {
        extension.registry['0'] = {'platformBrightness': 'dark'};
        // The read that follows the registration fails.
        extension.nextCallError = callFailure;
        await extension.register();
        await pumpEventQueue();
        expect(client.overrides.value, isEmpty);

        await client.updateOverrides({'boldText': true});

        expect(extension.registry, {
          '0': {'platformBrightness': 'dark', 'boldText': true},
        });
      },
    );

    test('writes run one at a time, each from the reply before it', () async {
      await extension.register();
      await pumpEventQueue();

      await Future.wait([
        client.updateOverrides({'boldText': true}),
        client.updateOverrides({'highContrast': true}),
      ]);

      expect(extension.registry['0'], {'boldText': true, 'highContrast': true});
    });

    test('a call that throws does not stop the calls after it', () async {
      await extension.register();
      await pumpEventQueue();

      // JSON cannot encode NaN, so this write throws before it is sent.
      await client.updateOverrides({'textScaling': double.nan});
      await client.updateOverrides({'boldText': true});

      expect(extension.registry, {
        '0': {'boldText': true},
      });
    });

    test('forgets the overrides of an isolate that exits', () async {
      await extension.register();
      await pumpEventQueue();
      await client.updateOverrides({'boldText': true});

      // The read of the new isolate fails.
      extension.nextCallError = callFailure;
      await extension.hotRestart();
      await pumpEventQueue();

      expect(client.available.value, isTrue);
      expect(client.overrides.value, isEmpty);
    });

    test('reads the registry of the new isolate after a hot restart', () async {
      await extension.register();
      await pumpEventQueue();
      await client.updateOverrides({'boldText': true});
      expect(client.overrides.value, {'boldText': true});

      await extension.hotRestart();
      // App code of the new isolate overrides a metric before the client reads
      // the registry, which only the read reports.
      extension.registry['0'] = {'highContrast': true};
      await pumpEventQueue();

      expect(client.available.value, isTrue);
      expect(client.overrides.value, {'highContrast': true});
    });

    test(
      'does not wait for calls that an exited isolate never answers',
      () async {
        await extension.register();
        await pumpEventQueue();
        await client.updateOverrides({'boldText': true});
        extension.holdCalls = true;
        var interruptedWriteDone = false;
        unawaited(
          client
              .updateOverrides({'highContrast': true})
              .whenComplete(() => interruptedWriteDone = true),
        );
        await pumpEventQueue();
        expect(interruptedWriteDone, isFalse);

        // The app restarts before it answers the write, which empties the
        // registry.
        extension.holdCalls = false;
        await extension.hotRestart();
        unawaited(client.updateOverrides({'accessibleNavigation': true}));
        await pumpEventQueue();

        // Neither the caller of the write nor the calls after it wait for the
        // answer, which never comes.
        expect(interruptedWriteDone, isTrue);
        expect(extension.registry, {
          '0': {'accessibleNavigation': true},
        });
        expect(client.overrides.value, {'accessibleNavigation': true});
      },
    );

    test('dispose completes the calls that the app has not answered', () async {
      await extension.register();
      await pumpEventQueue();
      extension.holdCalls = true;
      var writeDone = false;
      unawaited(
        client
            .updateOverrides({'boldText': true})
            .whenComplete(() => writeDone = true),
      );
      await pumpEventQueue();
      expect(writeDone, isFalse);

      client.dispose();
      await pumpEventQueue();
      expect(writeDone, isTrue);

      // tearDown disposes the client again, so give it a new one.
      extension.holdCalls = false;
      client = ViewMetricsOverrideClient();
    });
  });
}
