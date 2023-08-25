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
  void _init({required bool connectToVmService}) {
    html.window.addEventListener('message', _handleMessage);
    // TODO(kenz) instead of connecting to the VM service through an event, load
    // the vm service URI through a query parameter like we already do in
    // DevTools app.
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
        // Do not handle messages that come from the [ExtensionManager] itself.
        if (extensionEvent.source == '$ExtensionManager') return;

        switch (extensionEvent.type) {
          case DevToolsExtensionEventType.ping:
            postMessageToDevTools(
              DevToolsExtensionEvent(DevToolsExtensionEventType.pong),
              targetOrigin: e.origin,
            );
            break;
          case DevToolsExtensionEventType.pong:
            // Ignore. DevTools extensions should not receive or handle pong
            // events.
            break;
          case DevToolsExtensionEventType.vmServiceConnection:
            final vmServiceUri = extensionEvent.data?['uri'] as String?;
            unawaited(
              connectToVmService(vmServiceUri).catchError((e) {
                // TODO(kenz): post a notification to DevTools for errors
                // or create an error panel for the extensions screens.
                print('Error connecting to VM service: $e');
              }),
            );
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

  /// Posts a [DevToolsExtensionEvent] to the DevTools extension host.
  ///
  /// If [targetOrigin] is null, the message will be posed to
  /// [html.window.origin].
  ///
  /// When [_debugUseSimulatedEnvironment] is true, this message will be posted
  /// to the same [html.window] that the extension is hosted in.
  void postMessageToDevTools(
    DevToolsExtensionEvent event, {
    String? targetOrigin,
  }) {
    final postWindow =
        _debugUseSimulatedEnvironment ? html.window : html.window.parent;
    postWindow?.postMessage(
      {
        ...event.toJson(),
        DevToolsExtensionEvent.sourceKey: '$ExtensionManager',
      },
      targetOrigin ?? html.window.origin!,
    );
  }

  Future<void> connectToVmService(String? vmServiceUri) async {
    if (vmServiceUri == null) return;

    final finishedCompleter = Completer<void>();
    final vmService = await connect<VmService>(
      uri: Uri.parse(vmServiceUri),
      finishedCompleter: finishedCompleter,
      createService: ({
        // ignore: avoid-dynamic, code needs to match API from VmService.
        required Stream<dynamic> /*String|List<int>*/ inStream,
        required void Function(String message) writeMessage,
        required Uri connectedUri,
      }) {
        return VmService(inStream, writeMessage);
      },
    );
    await serviceManager.vmServiceOpened(
      vmService,
      onClosed: finishedCompleter.future,
    );
  }
}
