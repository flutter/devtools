// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// @docImport 'message_port_connection.dart';
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:logging/logging.dart';
import 'package:web/web.dart';

import '../shared/globals.dart';
import 'vm_service_wrapper.dart';

final _log = Logger('message_port_connection');

/// How long the embedder has to connect a new port and answer `getVersion`.
const _connectTimeout = Duration(seconds: 10);

/// Connects to a VM service over a `MessagePort`, as described in
/// [messagePortUriScheme].
///
/// [finishedCompleter] is completed when the returned service is disposed.
Future<VmServiceWrapper> connectWithMessagePort({
  required Uri uri,
  required Completer<void> finishedCompleter,
}) async {
  final embedder = window.openerCrossOrigin ?? window.parentCrossOrigin;
  if (embedder == null) {
    throw UnsupportedError(
      'Connecting to a VM service over a MessagePort requires window.opener '
      'or window.parent.',
    );
  }
  final targetOrigin = uri.path;
  if (targetOrigin.isEmpty) {
    throw ArgumentError(
      'The messageport URI must specify a target origin, e.g., '
      'messageport:https://example.com',
    );
  }
  // A new channel per connect, so reconnects and reloads just work.
  final channel = MessageChannel();
  embedder.postMessage(
    _ConnectMessage(action: 'connect', port: channel.port2),
    targetOrigin.toJS,
    [channel.port2].toJS,
  );

  final port = channel.port1;
  final messages = StreamController<Object>();
  port.onmessage = (MessageEvent event) {
    final data = event.data;
    if (data == null) {
      // The embedder closed the connection. The service disposes itself when
      // its stream is done.
      unawaited(messages.close());
    } else if (data.isA<JSString>()) {
      messages.add((data as JSString).toDart);
    } else if (data.isA<JSUint8Array>()) {
      messages.add((data as JSUint8Array).toDart);
    } else {
      _log.warning('Ignoring VM service message of unsupported type: $data');
    }
  }.toJS;

  late final StreamSubscription<Event> pageHideSubscription;
  void closePort() {
    if (finishedCompleter.isCompleted) return;
    unawaited(pageHideSubscription.cancel());
    port
      ..postMessage(null)
      ..onmessage = null
      ..close();
    unawaited(messages.close());
    finishedCompleter.complete();
  }

  // Close the port on pagehide, matching browser WebSocket behavior.
  pageHideSubscription = const EventStreamProvider<Event>(
    'pagehide',
  ).forTarget(window).listen((_) => closePort());

  final service = VmServiceWrapper.defaultFactory(
    inStream: messages.stream,
    writeMessage: (message) => port.postMessage(message.toJS),
    disposeHandler: () async => closePort(),
    wsUri: uri.toString(),
    trackFutures: integrationTestMode,
  );

  // Verify the connection, like `connect` from `package:devtools_shared` does.
  try {
    await service.getVersion().timeout(_connectTimeout);
  } catch (_) {
    await service.dispose();
    rethrow;
  }
  return service;
}

/// The message that asks the embedder to connect the transferred `port` to a
/// VM service.
extension type _ConnectMessage._(JSObject _) implements JSObject {
  external factory _ConnectMessage({String action, MessagePort port});
}
