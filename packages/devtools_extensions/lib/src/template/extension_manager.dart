// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'devtools_extension.dart';

final _log = Logger('devtools_extensions/extension_manager');

class ExtensionManager {
  final _registeredEventHandlers =
      <DevToolsExtensionEventType, ExtensionEventHandler>{};

  void registerEventHandler(
    DevToolsExtensionEventType event,
    ExtensionEventHandler handler,
  ) {
    _registeredEventHandlers[event] = handler;
  }

  // ignore: unused_element, false positive due to part files
  void _init() {
    html.window.addEventListener('message', _handleMessage);
  }

  // ignore: unused_element, false positive due to part files
  void _dispose() {
    _registeredEventHandlers.clear();
    html.window.removeEventListener('message', _handleMessage);
  }

  void _handleMessage(html.Event e) {
    if (e is html.MessageEvent) {
      final extensionEvent = DevToolsExtensionEvent.tryParse(e.data);
      if (extensionEvent != null) {
        switch (extensionEvent.type) {
          case DevToolsExtensionEventType.ping:
            html.window.parent?.postMessage(
              DevToolsExtensionEvent.pong.toJson(),
              e.origin,
            );
            break;
          case DevToolsExtensionEventType.pong:
            // Ignore. DevTools Plugins should not receive/handle these events.
            break;
          case DevToolsExtensionEventType.unknown:
            _log.info('Unrecognized event received by extension: ${e.data}');
            break;
          default:
        }
        _registeredEventHandlers[extensionEvent.type]?.call(extensionEvent);
      }
    }
  }

  void postMessageToDevTools(DevToolsExtensionEvent event) {
    html.window.parent?.postMessage(event.toJson(), html.window.origin!);
  }
}
