// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'vm_service_wrapper.dart';

/// Extracts the target origin for window.postMessage from [uri].
///
/// The URI is expected in the form `post-message:<origin>` (e.g.
/// `post-message:https://dartpad.dev` or `post-message:*`).
String _extractTargetOrigin(Uri uri) {
  if (uri.path.isEmpty || uri.path == '*') {
    return '*';
  }
  final target = Uri.tryParse(uri.path);
  if (target != null && target.hasScheme && target.hasAuthority) {
    return target.origin;
  }
  return uri.path;
}

/// Connects to a Dart VM service via a browser `MessagePort`.
///
/// Creates a [web.MessageChannel], transfers `port1` to `window.parent`
/// via a postMessage with payload `{'vmServicePort': port1}`, and binds
/// `port2` to a [VmServiceWrapper].
Future<VmServiceWrapper> connectWithPostMessage({
  required Uri uri,
  required Completer<void> finishedCompleter,
}) async {
  final targetOrigin = _extractTargetOrigin(uri);
  final channel = web.MessageChannel();
  // ignore: avoid-dynamic, mirrors types of [Stream<dynamic> inStream] in [VmService].
  final inStreamController = StreamController<dynamic>();

  final message = {'vmServicePort': channel.port1}.jsify();
  web.window.parent?.postMessage(
    message,
    web.WindowPostMessageOptions(
      targetOrigin: targetOrigin,
      transfer: [channel.port1].toJS,
    ),
  );

  channel.port2.onmessage = ((web.MessageEvent event) {
    final data = event.data;
    if (data != null) {
      if (data.isA<JSString>()) {
        inStreamController.add((data as JSString).toDart);
      } else if (data.isA<JSUint8Array>()) {
        inStreamController.add((data as JSUint8Array).toDart);
      } else if (data.isA<JSArrayBuffer>()) {
        inStreamController.add((data as JSArrayBuffer).toDart.asUint8List());
      } else {
        inStreamController.add(jsonEncode(data.dartify()));
      }
    }
  }).toJS;
  channel.port2.start();

  final service = VmServiceWrapper.defaultFactory(
    inStream: inStreamController.stream,
    writeMessage: (String msg) {
      channel.port2.postMessage(msg.toJS);
    },
    streamClosed: finishedCompleter.future,
    wsUri: uri.toString(),
  );

  unawaited(
    finishedCompleter.future.then((_) async {
      channel.port2.close();
      await inStreamController.close();
      await service.dispose();
    }),
  );

  // Validate the connection with a getVersion call.
  await service.getVersion();

  return service;
}
