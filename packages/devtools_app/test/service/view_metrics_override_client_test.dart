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
      final otherClient = ViewMetricsOverrideClient();
      addTearDown(otherClient.dispose);
      await pumpEventQueue();
      expect(otherClient.available.value, isTrue);
      expect(otherClient.overrides.value, {'platformBrightness': 'dark'});
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

    test('failed calls keep the overrides and the restore', () async {
      final error = RPCError(
        viewMetricsOverride,
        RPCErrorKind.kServerError.code,
        'Failed',
      );
      await extension.register();
      await pumpEventQueue();
      await client.updateOverrides({'boldText': true});

      extension.nextCallError = error;
      await client.updateOverrides({'highContrast': true});
      expect(extension.registry, {
        '0': {'boldText': true},
      });
      expect(client.overrides.value, {'boldText': true});

      // The first read after the hot restart fails, so the restore reads again.
      extension.nextCallError = error;
      await extension.hotRestart();
      await pumpEventQueue();
      expect(extension.registry, {
        '0': {'boldText': true},
      });
    });

    test('writes run one at a time, each from the reply before it', () async {
      await extension.register();
      await pumpEventQueue();

      await Future.wait([
        client.updateOverrides({'boldText': true}),
        client.updateOverrides({'highContrast': true}),
      ]);

      expect(extension.registry['0'], {'boldText': true, 'highContrast': true});
    });

    test('sets its metrics again after a hot restart', () async {
      extension.registry['0'] = {'platformBrightness': 'dark'};
      await extension.register();
      await pumpEventQueue();
      await client.updateOverrides({
        'boldText': true,
        'textScaling': [
          [1, 2],
        ],
      });
      await client.updateOverrides({'textScaling': null});
      extension.callFromOtherClient({
        'viewId': '0',
        'overrides': jsonEncode({
          'platformBrightness': 'dark',
          'boldText': false,
        }),
      });
      await pumpEventQueue();

      extension.calls.clear();
      await extension.hotRestart();
      await pumpEventQueue();

      expect(extension.calls, [
        <String, String>{},
        {'viewId': '0', 'overrides': anything},
      ]);
      // Only the metrics that this client set and that the app still had are
      // set again, with the values that they had. The metrics of other clients
      // are theirs to set again.
      expect(extension.registry, {
        '0': {'boldText': false},
      });
      expect(client.overrides.value, {'boldText': false});
    });

    test(
      'does not wait for calls that an exited isolate never answers',
      () async {
        await extension.register();
        await pumpEventQueue();
        await client.updateOverrides({'boldText': true});
        extension.calls.clear();
        await extension.hotRestart();
        // Let the new isolate be read, and the restore be sent.
        for (var i = 0; i < 5 && extension.calls.length < 2; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(extension.calls, [
          <String, String>{},
          {'viewId': '0', 'overrides': '{"boldText":true}'},
        ]);
        expect(extension.registry, isEmpty);

        // The app restarts again before it answers the restore, while a write
        // waits for the restore in the queue.
        unawaited(client.updateOverrides({'highContrast': true}));
        extension.calls.clear();
        await extension.hotRestart();
        await pumpEventQueue();

        // The write is dropped, and the new isolate gets the restore.
        expect(extension.calls, [
          <String, String>{},
          {'viewId': '0', 'overrides': '{"boldText":true}'},
        ]);
        expect(extension.registry, {
          '0': {'boldText': true},
        });
      },
    );
  });
}
