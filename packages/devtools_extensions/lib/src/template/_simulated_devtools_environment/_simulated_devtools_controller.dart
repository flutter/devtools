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

  void init() {
    html.window.addEventListener('message', _handleMessage);
    addAutoDisposeListener(serviceManager.connectedState, () {
      if (!serviceManager.connectedState.value.connected) {
        vmServiceConnectionChanged(uri: null);
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
    html.window.removeEventListener('message', _handleMessage);
    super.dispose();
  }

  @override
  void ping() {
    _postMessageToExtension(
      DevToolsExtensionEvent(DevToolsExtensionEventType.ping),
    );
  }

  @override
  void vmServiceConnectionChanged({required String? uri}) {
    // TODO(kenz): add some validation and error handling if [uri] is bad input.
    final normalizedUri =
        uri != null ? normalizeVmServiceUri(uri).toString() : null;
    final event = DevToolsExtensionEvent(
      DevToolsExtensionEventType.vmServiceConnection,
      data: {'uri': normalizedUri},
    );
    _postMessageToExtension(event);
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
