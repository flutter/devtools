// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// @docImport 'message_port_connection.dart';
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart';

import '../shared/globals.dart';
import 'vm_service_wrapper.dart';

final _log = Logger('message_port_connection');

/// Connects to a VM service over a `MessagePort`, as described in
/// [messagePortUriScheme].
///
/// [finishedCompleter] is completed when the returned service is disposed.
Future<VmServiceWrapper> connectWithMessagePort({
  required Uri uri,
  required Completer<void> finishedCompleter,
}) async {
  final parent = window.parent;
  if (parent == null) {
    throw UnsupportedError(
      'Connecting to a VM service over a MessagePort requires window.parent.',
    );
  }
  final targetOrigin = uri.path;
  // A new channel per connect, so reconnects and reloads just work.
  final channel = MessageChannel();
  parent.postMessage(
    _ConnectMessage(action: 'connect', port: channel.port2),
    targetOrigin.toJS,
    [channel.port2].toJS,
  );

  final port = channel.port1;
  final messages = StreamController<Object>();
  port.onmessage = (MessageEvent event) {
    final data = event.data;
    if (data.isA<JSString>()) {
      messages.add((data as JSString).toDart);
    } else if (data.isA<JSUint8Array>()) {
      messages.add((data as JSUint8Array).toDart);
    } else {
      _log.warning('Ignoring VM service message of unsupported type: $data');
    }
  }.toJS;

  final service = VmServiceWrapper.defaultFactory(
    inStream: messages.stream,
    writeMessage: (message) => port.postMessage(message.toJS),
    disposeHandler: () async {
      port
        ..onmessage = null
        ..close();
      unawaited(messages.close());
      finishedCompleter.safeComplete();
    },
    wsUri: uri.toString(),
    trackFutures: integrationTestMode,
  );

  // Verify the connection, like `connect` from `package:devtools_shared` does.
  try {
    await service.getVersion();
  } catch (_) {
    await service.dispose();
    rethrow;
  }
  return service;
}

/// The message that asks the page embedding DevTools to connect the
/// transferred `port` to a VM service.
extension type _ConnectMessage._(JSObject _) implements JSObject {
  external factory _ConnectMessage({String action, MessagePort port});
}
