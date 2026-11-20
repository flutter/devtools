// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:devtools_extensions/api.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:devtools_extensions/src/template/_simulated_devtools_environment/_simulated_devtools_environment.dart';
import 'package:devtools_extensions/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart';

void main() {
  MessageEvent createExtensionMessageEvent({
    required String origin,
    required MessageEventSource? source,
    DevToolsExtensionEvent? event,
  }) {
    final extensionEvent =
        event ??
        DevToolsExtensionEvent(
          DevToolsExtensionEventType.themeUpdate,
          data: {
            ExtensionEventParameters.theme:
                ExtensionEventParameters.themeValueLight,
          },
        );
    return MessageEvent(
      'message',
      MessageEventInit(
        data: extensionEvent.toJson().jsify(),
        origin: origin,
        source: source,
      ),
    );
  }

  group('isAllowedDevToolsOrigin', () {
    test('accepts matching window origin', () {
      expect(
        isAllowedDevToolsOrigin(
          'http://localhost:9100',
          windowOrigin: 'http://localhost:9100',
        ),
        isTrue,
      );
      expect(
        isAllowedDevToolsOrigin(
          'https://devtools.example.com',
          windowOrigin: 'https://devtools.example.com',
        ),
        isTrue,
      );
    });

    test('accepts loopback HTTP(S) origins', () {
      expect(
        isAllowedDevToolsOrigin(
          'http://localhost:9100',
          windowOrigin: 'http://127.0.0.1:9101',
        ),
        isTrue,
      );
      expect(
        isAllowedDevToolsOrigin(
          'http://127.0.0.1:9100',
          windowOrigin: 'http://localhost:9101',
        ),
        isTrue,
      );
      expect(
        isAllowedDevToolsOrigin(
          'http://[::1]:9100',
          windowOrigin: 'http://localhost:9101',
        ),
        isTrue,
      );
      expect(
        isAllowedDevToolsOrigin(
          'https://localhost:9100',
          windowOrigin: 'http://localhost:9101',
        ),
        isTrue,
      );
    });

    test('rejects foreign, opaque, and malformed origins', () {
      const windowOrigin = 'http://localhost:9100';
      for (final invalidOrigin in [
        'https://evil.example.com',
        'http://localhost.evil.com:9100',
        'http://127.0.0.1.evil.com:9100',
        'http://user@localhost:9100',
        'http://localhost:9100/path',
        'http://localhost:9100?query=1',
        'http://localhost:9100#frag',
        'http://localhost:',
        'HTTP://LOCALHOST:9100',
        'http://localhost:80',
        'javascript:alert(1)',
        'file://',
        'null',
        '',
      ]) {
        expect(
          isAllowedDevToolsOrigin(invalidOrigin, windowOrigin: windowOrigin),
          isFalse,
          reason: 'Expected origin "$invalidOrigin" to be rejected',
        );
      }

      // Opaque or empty windowOrigin must not allow any origin, including
      // loopback or 'null'.
      expect(isAllowedDevToolsOrigin('null', windowOrigin: 'null'), isFalse);
      expect(
        isAllowedDevToolsOrigin('http://localhost:9100', windowOrigin: 'null'),
        isFalse,
      );
      expect(
        isAllowedDevToolsOrigin('http://localhost:9100', windowOrigin: ''),
        isFalse,
      );

      // Non-loopback windowOrigin must not allow loopback origins.
      expect(
        isAllowedDevToolsOrigin(
          'http://localhost:9100',
          windowOrigin: 'https://devtools.example.com',
        ),
        isFalse,
      );
      expect(
        isAllowedDevToolsOrigin(
          'http://127.0.0.1:9100',
          windowOrigin: 'https://devtools.example.com',
        ),
        isFalse,
      );
    });
  });

  group('tryParseExtensionEvent', () {
    test('returns null for MessageEvent with null data payload', () {
      final event = MessageEvent('message', MessageEventInit(data: null));
      expect(tryParseExtensionEvent(event), isNull);
    });

    test('returns null for non-MessageEvent', () {
      expect(tryParseExtensionEvent(Event('message')), isNull);
    });

    test('parses valid extension MessageEvent', () {
      final event = createExtensionMessageEvent(
        origin: window.origin,
        source: window,
      );
      final parsed = tryParseExtensionEvent(event);
      expect(parsed, isNotNull);
      expect(parsed!.type, DevToolsExtensionEventType.themeUpdate);
    });
  });

  group('ExtensionManager message validation', () {
    late List<LogRecord> warningLogs;
    late HTMLIFrameElement otherIFrame;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      warningLogs = [];
      final previousLevel = Logger.root.level;
      Logger.root.level = Level.WARNING;
      final sub = Logger.root.onRecord.listen(warningLogs.add);
      addTearDown(() {
        sub.cancel();
        Logger.root.level = previousLevel;
      });

      otherIFrame = HTMLIFrameElement();
      document.body!.append(otherIFrame);
      addTearDown(() => otherIFrame.remove());
    });

    group('embedded mode (window.parent)', () {
      late ExtensionManager manager;
      late List<DevToolsExtensionEvent> receivedEvents;

      setUp(() {
        manager = ExtensionManager(useSimulatedEnvironment: false);
        receivedEvents = [];
        manager.registerEventHandler(
          DevToolsExtensionEventType.themeUpdate,
          receivedEvents.add,
        );
      });

      test('processes messages from window.origin and loopback origins '
          'with window.parent source', () {
        for (final origin in [
          window.origin,
          'http://localhost:9100',
          'http://127.0.0.1:9100',
        ]) {
          manager.handleMessage(
            createExtensionMessageEvent(origin: origin, source: window.parent),
          );
        }

        expect(receivedEvents, hasLength(3));
        expect(warningLogs, isEmpty);
      });

      test('drops and logs messages from mismatched origins', () {
        for (final badOrigin in [
          'https://evil.example.com',
          'http://localhost.evil.com:9100',
          'null',
          '',
        ]) {
          manager.handleMessage(
            createExtensionMessageEvent(
              origin: badOrigin,
              source: window.parent,
            ),
          );
        }

        expect(receivedEvents, isEmpty);
        expect(warningLogs, hasLength(4));
      });

      test('drops messages from unexpected window sources without warning', () {
        manager.handleMessage(
          createExtensionMessageEvent(origin: window.origin, source: window),
        );
        manager.handleMessage(
          createExtensionMessageEvent(
            origin: window.origin,
            source: otherIFrame.contentWindow,
          ),
        );

        expect(receivedEvents, isEmpty);
        expect(warningLogs, isEmpty);
      });

      test('drops and logs messages with null source (detached frame)', () {
        manager.handleMessage(
          createExtensionMessageEvent(origin: window.origin, source: null),
        );

        expect(receivedEvents, isEmpty);
        expect(warningLogs, hasLength(1));
      });

      test('ignores non-MessageEvent events', () {
        manager.handleMessage(Event('message'));
        expect(receivedEvents, isEmpty);
      });
    });

    group('simulated environment mode (window)', () {
      late ExtensionManager manager;
      late List<DevToolsExtensionEvent> receivedEvents;

      setUp(() {
        manager = ExtensionManager(useSimulatedEnvironment: true);
        receivedEvents = [];
        manager.registerEventHandler(
          DevToolsExtensionEventType.themeUpdate,
          receivedEvents.add,
        );
      });

      test('processes messages from window.origin with window source', () {
        manager.handleMessage(
          createExtensionMessageEvent(origin: window.origin, source: window),
        );

        expect(receivedEvents, hasLength(1));
        expect(warningLogs, isEmpty);
      });

      test(
        'drops messages from window.parent in simulated mode without warning',
        () {
          manager.handleMessage(
            createExtensionMessageEvent(
              origin: window.origin,
              source: window.parent,
            ),
          );

          expect(receivedEvents, isEmpty);
          expect(warningLogs, isEmpty);
        },
      );

      test('drops and logs messages with null source in simulated mode', () {
        manager.handleMessage(
          createExtensionMessageEvent(origin: window.origin, source: null),
        );

        expect(receivedEvents, isEmpty);
        expect(warningLogs, hasLength(1));
      });

      test(
        'drops and logs messages from mismatched origins in simulated mode',
        () {
          for (final badOrigin in [
            'https://evil.example.com',
            'http://localhost:9999',
          ]) {
            manager.handleMessage(
              createExtensionMessageEvent(origin: badOrigin, source: window),
            );
          }

          expect(receivedEvents, isEmpty);
          expect(warningLogs, hasLength(2));
        },
      );
    });

    testWidgets('validates dispatched window message events end-to-end', (
      tester,
    ) async {
      final received = <DevToolsExtensionEvent>[];
      await tester.pumpWidget(
        DevToolsExtension(
          eventHandlers: {DevToolsExtensionEventType.themeUpdate: received.add},
          child: const SizedBox(),
        ),
      );

      // Spoofed origin should be dropped.
      window.dispatchEvent(
        createExtensionMessageEvent(
          origin: 'https://evil.example.com',
          source: window.parent,
        ),
      );
      // Null source should be dropped.
      window.dispatchEvent(
        createExtensionMessageEvent(origin: window.origin, source: null),
      );
      // Wrong source should be dropped.
      window.dispatchEvent(
        createExtensionMessageEvent(origin: window.origin, source: window),
      );
      expect(received, isEmpty);

      // Valid origin and source should be processed.
      window.dispatchEvent(
        createExtensionMessageEvent(
          origin: window.origin,
          source: window.parent,
        ),
      );
      expect(received, hasLength(1));
    });
  });

  group('SimulatedDevToolsController message validation', () {
    late SimulatedDevToolsController controller;
    late HTMLIFrameElement otherIFrame;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      controller = SimulatedDevToolsController();
      addTearDown(controller.dispose);

      otherIFrame = HTMLIFrameElement();
      document.body!.append(otherIFrame);
      addTearDown(() => otherIFrame.remove());
    });

    test('processes messages from window.origin with window source', () {
      controller.handleMessage(
        createExtensionMessageEvent(origin: window.origin, source: window),
      );

      expect(controller.messageLogs.value, hasLength(1));
    });

    test('drops messages from mismatched origins', () {
      for (final badOrigin in [
        'https://evil.example.com',
        'http://localhost:9999',
        'null',
        '',
      ]) {
        controller.handleMessage(
          createExtensionMessageEvent(origin: badOrigin, source: window),
        );
      }

      expect(controller.messageLogs.value, isEmpty);
    });

    test('drops messages from unexpected or null sources', () {
      controller.handleMessage(
        createExtensionMessageEvent(
          origin: window.origin,
          source: window.parent,
        ),
      );
      controller.handleMessage(
        createExtensionMessageEvent(
          origin: window.origin,
          source: otherIFrame.contentWindow,
        ),
      );
      controller.handleMessage(
        createExtensionMessageEvent(origin: window.origin, source: null),
      );

      expect(controller.messageLogs.value, isEmpty);
    });

    test('ignores non-MessageEvent events', () {
      controller.handleMessage(Event('message'));
      expect(controller.messageLogs.value, isEmpty);
    });
  });
}
