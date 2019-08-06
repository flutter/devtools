// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' hide Event;
import 'dart:typed_data';

import 'package:sse/client/sse_client.dart';
import 'package:vm_service/utils.dart';

import 'vm_service_wrapper.dart';

void _connectWithSse(
  Uri uri,
  Completer<VmServiceWrapper> connectedCompleter,
  Completer<Null> finishedCompleter,
) {
  uri = uri.scheme == 'sse'
      ? uri.replace(scheme: 'http')
      : uri.replace(scheme: 'https');
  final SseClient client = SseClient('$uri');
  client.onOpen.listen((_) {
    final Stream<String> stream = client.stream.asBroadcastStream();
    stream.listen((_) {}, onError: (error) {
      if (!connectedCompleter.isCompleted) {
        connectedCompleter.completeError(error);
      }
    });

    final VmServiceWrapper service = VmServiceWrapper.fromNewVmService(
      stream,
      (String message) => client.sink.add(message),
    );

    client.sink.done.then((_) {
      finishedCompleter.complete();
      service.dispose();
    });

    connectedCompleter.complete(service);
  });
}

void _connectWithWebSocket(
  Uri uri,
  Completer<VmServiceWrapper> connectedCompleter,
  Completer<Null> finishedCompleter,
) {
  // Map the URI (which may be Observatory web app) to a WebSocket URI for
  // the VM service.
  uri = convertToWebSocketUrl(serviceProtocolUrl: uri);
  final WebSocket ws = WebSocket(uri.toString());

  ws.onOpen.listen((_) {
    final Stream<dynamic> inStream =
        convertBroadcastToSingleSubscriber(ws.onMessage)
            .asyncMap<dynamic>((MessageEvent e) {
      if (e.data is String) {
        return e.data;
      } else {
        final FileReader fileReader = FileReader();
        fileReader.readAsArrayBuffer(e.data);
        return fileReader.onLoadEnd.first.then<ByteData>((ProgressEvent _) {
          final Uint8List list = fileReader.result;
          return ByteData.view(list.buffer);
        });
      }
    });

    final VmServiceWrapper service = VmServiceWrapper.fromNewVmService(
      inStream,
      (String message) => ws.send(message),
    );

    ws.onClose.listen((_) {
      finishedCompleter.complete();
      service.dispose();
    });

    connectedCompleter.complete(service);
  });

  ws.onError.listen((dynamic e) {
    if (!connectedCompleter.isCompleted) {
      connectedCompleter.completeError(e);
    }
  });
}

Future<VmServiceWrapper> connect(Uri uri, Completer<Null> finishedCompleter) {
  final Completer<VmServiceWrapper> connectedCompleter =
      Completer<VmServiceWrapper>();
  if (uri.scheme == 'sse' || uri.scheme == 'sses') {
    _connectWithSse(uri, connectedCompleter, finishedCompleter);
  } else {
    _connectWithWebSocket(uri, connectedCompleter, finishedCompleter);
  }
  return connectedCompleter.future;
}

/// Wraps a broadcast stream as a single-subscription stream to workaround
/// events being dropped for DOM/WebSocket broadcast streams when paused
/// (such as in an asyncMap).
/// https://github.com/dart-lang/sdk/issues/34656
Stream<T> convertBroadcastToSingleSubscriber<T>(Stream<T> stream) {
  final StreamController<T> controller = StreamController<T>();
  StreamSubscription<T> subscription;
  controller.onListen =
      () => subscription = stream.listen((T e) => controller.add(e));
  controller.onCancel = () => subscription.cancel();
  return controller.stream;
}
