// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:devtools_app/src/service/message_port_connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart';

void main() {
  test('connects and closes over a port posted to the parent', () async {
    // The test runner loads each test suite in a same-origin iframe, so the
    // test can play the page embedding DevTools.
    final connectEvent = EventStreamProviders.messageEvent
        .forTarget(window.parent)
        .firstWhere((event) => event.source.strictEquals(window).toDart);
    final finishedCompleter = Completer<void>();
    final serviceFuture = connectWithMessagePort(
      uri: Uri.parse('messageport:${window.location.origin}'),
      finishedCompleter: finishedCompleter,
    );

    final message = (await connectEvent).data as _ConnectMessage;
    expect(message.action, 'connect');
    // Play the VM service. DevTools only calls `getSupportedProtocols` and
    // `getVersion` here.
    final port = message.port;
    final closedByDevTools = Completer<void>();
    port.onmessage = (MessageEvent event) {
      final data = event.data;
      if (data == null) {
        closedByDevTools.complete();
        return;
      }
      final request =
          jsonDecode((data as JSString).toDart) as Map<String, Object?>;
      port.postMessage(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': request['id'],
          'result': request['method'] == 'getVersion'
              ? {'type': 'Version', 'major': 4, 'minor': 23}
              : {'type': 'ProtocolList', 'protocols': <Object?>[]},
        }).toJS,
      );
    }.toJS;

    final service = await serviceFuture;
    expect((await service.getVersion()).major, 4);

    // Either side posts `null` to close the connection.
    port.postMessage(null);
    await closedByDevTools.future;
    expect(finishedCompleter.isCompleted, isTrue);
  });
}

/// The message that DevTools posts to `window.parent`.
extension type _ConnectMessage._(JSObject _) implements JSObject {
  external String get action;

  external MessagePort get port;
}
