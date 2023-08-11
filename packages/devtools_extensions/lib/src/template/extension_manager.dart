// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'devtools_extension.dart';

final _log = Logger('devtools_extensions/extension_manager');

class ExtensionManager {
  final appManager = ConnectedAppManager();

  final _registeredEventHandlers =
      <DevToolsExtensionEventType, ExtensionEventHandler>{};

  void registerEventHandler(
    DevToolsExtensionEventType event,
    ExtensionEventHandler handler,
  ) {
    _registeredEventHandlers[event] = handler;
  }

  // ignore: unused_element, false positive due to part files
  void _init({required bool connectToVmService}) {
    html.window.addEventListener('message', _handleMessage);
    if (connectToVmService) {
      // Request the vm service uri for the connected app. DevTools will
      // respond with a [DevToolsPluginEventType.connectedVmService] event with
      // containing the currently connected app's vm service URI.
      postMessageToDevTools(
        DevToolsExtensionEvent(DevToolsExtensionEventType.vmServiceConnection),
      );
    }
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
            // Ignore. DevTools extensions should not receive or handle pong
            // events.
            break;
          case DevToolsExtensionEventType.vmServiceConnection:
            final vmServiceUri = extensionEvent.data?['uri'] as String?;
            unawaited(appManager.connectToVmService(vmServiceUri));
            break;
          case DevToolsExtensionEventType.unknown:
          default:
            _log.warning(
              'Unrecognized event received by extension: '
              '(${extensionEvent.type} - ${e.data}',
            );
        }
        _registeredEventHandlers[extensionEvent.type]?.call(extensionEvent);
      }
    }
  }

  void postMessageToDevTools(DevToolsExtensionEvent event) {
    html.window.parent?.postMessage(event.toJson(), html.window.origin!);
  }
}
