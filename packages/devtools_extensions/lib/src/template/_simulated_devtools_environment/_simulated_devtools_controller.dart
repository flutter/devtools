// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '_simulated_devtools_environment.dart';

class _SimulatedDevToolsController extends DisposableController
    implements DevToolsExtensionHostInterface {
  /// Logs of the post message communication that goes back and forth between
  /// the extension and the simulated DevTools environment.
  final messageLogs = ListValueNotifier<_PostMessageLogEntry>([]);

  void init() {
    html.window.addEventListener('message', _handleMessage);
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
  void vmServiceConnectionChanged({String? uri}) {
    uri = 'http://127.0.0.1:60851/fH-kAEXc7MQ=/';
    // TODO(kenz): add some validation and error handling if [uri] is bad input.
    final normalizedUri = normalizeVmServiceUri(uri!);
    final event = DevToolsExtensionEvent(
      DevToolsExtensionEventType.vmServiceConnection,
      data: {'uri': normalizedUri.toString()},
    );
    _postMessageToExtension(event);
  }

  @override
  void onEventReceived(
    DevToolsExtensionEvent event, {
    void Function()? onUnknownEvent,
  }) {
    messageLogs.add(
      _PostMessageLogEntry(
        source: _PostMessageSource.extension,
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
      _PostMessageLogEntry(
        source: _PostMessageSource.devtools,
        data: eventJson,
      ),
    );
  }
}

class _PostMessageLogEntry {
  _PostMessageLogEntry({required this.source, required this.data})
      : timestamp = DateTime.now();

  final _PostMessageSource source;
  final Map<String, Object?> data;
  final DateTime timestamp;
}

enum _PostMessageSource {
  devtools,
  extension;

  String get display {
    return name.toUpperCase();
  }
}
