// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:devtools_app/src/extensions/embedded/_controller_web.dart';
import 'package:devtools_app/src/extensions/embedded/_view_web.dart';
import 'package:devtools_app/src/shared/managers/notifications.dart';
import 'package:devtools_app/src/shared/preferences/preferences.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_extensions/api.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart';

void main() {
  group('ExtensionIFrameController message validation', () {
    late HTMLIFrameElement extensionIFrame;
    late HTMLIFrameElement otherIFrame;
    late _TestEmbeddedExtensionController embeddedController;
    late ExtensionIFrameController iFrameController;
    late NotificationService testNotificationService;

    const expectedOrigin = 'http://localhost:9100';
    const extensionUrl =
        '$expectedOrigin/devtools_extensions/test_ext/index.html?theme=dark';

    MessageEvent createNotificationEvent({
      required String origin,
      required MessageEventSource? source,
      String message = 'hello from extension',
    }) {
      return MessageEvent(
        'message',
        MessageEventInit(
          data: ShowNotificationExtensionEvent(
            message: message,
          ).toJson().jsify(),
          origin: origin,
          source: source,
        ),
      );
    }

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();

      testNotificationService = NotificationService();
      setGlobal(NotificationService, testNotificationService);
      setGlobal(PreferencesController, PreferencesController());

      extensionIFrame = HTMLIFrameElement();
      document.body!.append(extensionIFrame);

      otherIFrame = HTMLIFrameElement();
      document.body!.append(otherIFrame);

      embeddedController = _TestEmbeddedExtensionController(
        extensionUrl: extensionUrl,
        testIFrame: extensionIFrame,
      );
      iFrameController = ExtensionIFrameController(embeddedController)..init();
    });

    tearDown(() {
      iFrameController.dispose();
      embeddedController.dispose();
      extensionIFrame.remove();
      otherIFrame.remove();
      removeGlobal(NotificationService);
      removeGlobal(PreferencesController);
    });

    test(
      'processes messages matching extension origin and iframe contentWindow',
      () {
        expect(extensionIFrame.contentWindow, isNotNull);

        window.dispatchEvent(
          createNotificationEvent(
            origin: expectedOrigin,
            source: extensionIFrame.contentWindow,
            message: 'valid message',
          ),
        );

        expect(testNotificationService.activeMessages, hasLength(1));
        expect(
          testNotificationService.activeMessages.single.text,
          'valid message',
        );
      },
    );

    test('rejects messages from mismatched origins', () {
      for (final badOrigin in [
        'https://evil.example.com',
        'http://localhost:9999',
        'http://127.0.0.1:9100',
        'null',
        '',
      ]) {
        window.dispatchEvent(
          createNotificationEvent(
            origin: badOrigin,
            source: extensionIFrame.contentWindow,
            message: 'spoofed origin: $badOrigin',
          ),
        );
      }

      expect(testNotificationService.activeMessages, isEmpty);
    });

    test('rejects messages from unexpected window sources', () {
      window.dispatchEvent(
        createNotificationEvent(
          origin: expectedOrigin,
          source: window,
          message: 'from self window',
        ),
      );
      window.dispatchEvent(
        createNotificationEvent(
          origin: expectedOrigin,
          source: window.parent,
          message: 'from parent window',
        ),
      );
      window.dispatchEvent(
        createNotificationEvent(
          origin: expectedOrigin,
          source: otherIFrame.contentWindow,
          message: 'from other iframe',
        ),
      );

      expect(testNotificationService.activeMessages, isEmpty);
    });

    test('rejects messages with null source (detached iframe)', () {
      window.dispatchEvent(
        createNotificationEvent(
          origin: expectedOrigin,
          source: null,
          message: 'from detached iframe',
        ),
      );

      expect(testNotificationService.activeMessages, isEmpty);
    });

    test('ignores non-MessageEvent events', () {
      window.dispatchEvent(Event('message'));
      expect(testNotificationService.activeMessages, isEmpty);
    });

    test('safely rejects messages when extensionUrl is a data URI', () {
      final dataController = _TestEmbeddedExtensionController(
        extensionUrl: 'data:text/html;charset=utf-8,<html></html>',
        testIFrame: otherIFrame,
      );
      final dataIFrameController = ExtensionIFrameController(dataController)
        ..init();
      addTearDown(() {
        dataIFrameController.dispose();
        dataController.dispose();
      });

      window.dispatchEvent(
        createNotificationEvent(
          origin: 'null',
          source: otherIFrame.contentWindow,
          message: 'from data uri',
        ),
      );

      expect(testNotificationService.activeMessages, isEmpty);
    });
  });
}

class _TestEmbeddedExtensionController extends EmbeddedExtensionControllerImpl {
  _TestEmbeddedExtensionController({
    required String extensionUrl,
    required this.testIFrame,
  }) : _extensionUrl = extensionUrl,
       super(
         DevToolsExtensionConfig.parse({
           DevToolsExtensionConfig.nameKey: 'test_ext',
           DevToolsExtensionConfig.packageNameKey: 'test_ext',
           DevToolsExtensionConfig.issueTrackerKey:
               'https://example.com/issues',
           DevToolsExtensionConfig.versionKey: '1.0.0',
           DevToolsExtensionConfig.materialIconCodePointKey: '0xe15b',
           DevToolsExtensionConfig.extensionAssetsPathKey: '/path/to/ext',
           DevToolsExtensionConfig.devtoolsOptionsUriKey:
               'file:///path/to/devtools_options.yaml',
           DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
           DevToolsExtensionConfig.detectedFromStaticContextKey: 'false',
         }),
       );

  final String _extensionUrl;
  final HTMLIFrameElement testIFrame;

  @override
  String get extensionUrl => _extensionUrl;

  @override
  HTMLIFrameElement get extensionIFrame => testIFrame;
}
