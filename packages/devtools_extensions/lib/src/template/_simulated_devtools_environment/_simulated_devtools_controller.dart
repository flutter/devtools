// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '_simulated_devtools_environment.dart';

class _SimulatedDevToolsController extends DisposableController
    with AutoDisposeControllerMixin
    implements DevToolsExtensionHostInterface {
  /// Logs of the post message communication that goes back and forth between
  /// the extension and the simulated DevTools environment.
  final messageLogs = ListValueNotifier<_MessageLogEntry>([]);

  /// The listener that is added to simulated DevTools window to receive
  /// messages from the extension.
  ///
  /// We need to store this in a variable so that the listener is properly
  /// removed in [dispose].
  html.EventListener? _handleMessageListener;

  void init() {
    html.window.addEventListener(
      'message',
      _handleMessageListener = _handleMessage,
    );
    addAutoDisposeListener(serviceManager.connectedState, () {
      if (!serviceManager.connectedState.value.connected) {
        updateVmServiceConnection(uri: null);
        messageLogs.clear();
      }
    });
  }

  void _handleMessage(html.Event e) {
    if (e is html.MessageEvent) {
      final extensionEvent = DevToolsExtensionEvent.tryParse(e.data);
      if (extensionEvent != null) {
        // Do not handle messages that come from the
        // [_SimulatedDevToolsController] itself.
        if (extensionEvent.source == '$_SimulatedDevToolsController') return;

        onEventReceived(extensionEvent);
      }
    }
  }

  @override
  void dispose() {
    html.window.removeEventListener('message', _handleMessageListener);
    _handleMessageListener = null;
    super.dispose();
  }

  @override
  void ping() {
    _postMessageToExtension(
      DevToolsExtensionEvent(DevToolsExtensionEventType.ping),
    );
  }

  @override
  void updateVmServiceConnection({required String? uri}) {
    // TODO(https://github.com/flutter/devtools/issues/6416): write uri to the
    // window location query parameters so that the vm service connection
    // persists on hot restart.

    // TODO(kenz): add some validation and error handling if [uri] is bad input.
    final normalizedUri =
        uri != null ? normalizeVmServiceUri(uri).toString() : null;
    final event = DevToolsExtensionEvent(
      DevToolsExtensionEventType.vmServiceConnection,
      data: {
        ExtensionEventParameters.vmServiceConnectionUri: normalizedUri,
      },
    );
    _postMessageToExtension(event);
  }

  @override
  void updateTheme({required String theme}) {
    assert(
      theme == ExtensionEventParameters.themeValueLight ||
          theme == ExtensionEventParameters.themeValueDark,
    );
    _postMessageToExtension(
      DevToolsExtensionEvent(
        DevToolsExtensionEventType.themeUpdate,
        data: {ExtensionEventParameters.theme: theme},
      ),
    );
  }

  @override
  void onEventReceived(
    DevToolsExtensionEvent event, {
    void Function()? onUnknownEvent,
  }) {
    messageLogs.add(
      _MessageLogEntry(
        source: _MessageSource.extension,
        data: event.toJson(),
      ),
    );
  }

  void _postMessageToExtension(DevToolsExtensionEvent event) {
    final eventJson = event.toJson();
    html.window.postMessage(
      {
        ...eventJson,
        DevToolsExtensionEvent.sourceKey: '$_SimulatedDevToolsController',
      },
      html.window.origin!,
    );
    messageLogs.add(
      _MessageLogEntry(
        source: _MessageSource.devtools,
        data: eventJson,
      ),
    );
  }

  Future<void> hotReloadConnectedApp() async {
    await serviceManager.performHotReload();
    messageLogs.add(
      _MessageLogEntry(
        source: _MessageSource.info,
        message: 'Hot reload performed on connected app',
      ),
    );
  }

  Future<void> hotRestartConnectedApp() async {
    await serviceManager.performHotRestart();
    messageLogs.add(
      _MessageLogEntry(
        source: _MessageSource.info,
        message: 'Hot restart performed on connected app',
      ),
    );
  }

  void toggleTheme() {
    final darkThemeEnabled = extensionManager.darkThemeEnabled.value;
    updateTheme(
      theme: darkThemeEnabled
          ? ExtensionEventParameters.themeValueLight
          : ExtensionEventParameters.themeValueDark,
    );
  }

  @override
  void forceReload() {
    _postMessageToExtension(
      DevToolsExtensionEvent(DevToolsExtensionEventType.forceReload),
    );
  }
}

class _MessageLogEntry {
  _MessageLogEntry({required this.source, this.data, this.message})
      : timestamp = DateTime.now();

  final _MessageSource source;
  final Map<String, Object?>? data;
  final String? message;
  final DateTime timestamp;
}

enum _MessageSource {
  devtools,
  extension,
  info;

  String get display {
    return name.toUpperCase();
  }
}
