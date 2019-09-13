// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:html_shim/html.dart' hide Event;
import 'package:sse/client/sse_client.dart';
import 'package:vm_service/utils.dart';

import 'vm_service_wrapper.dart';

void _connectWithSse(
  Uri uri,
  Completer<VmServiceWrapper> connectedCompleter,
  Completer<void> finishedCompleter,
) {
  uri = uri.scheme == 'sse'
      ? uri.replace(scheme: 'http')
      : uri.replace(scheme: 'https');
  final client = SseClient('$uri');
  final Stream<String> stream = client.stream.asBroadcastStream();
  client.onOpen.listen((_) {
    final service = VmServiceWrapper.fromNewVmService(
      stream,
      client.sink.add,
    );

    client.sink.done.whenComplete(() {
      finishedCompleter.complete();
      service.dispose();
    });

    connectedCompleter.complete(service);
  });

  stream.drain().catchError((error) {
    if (!connectedCompleter.isCompleted) {
      connectedCompleter.completeError(error);
    }
  });
}

void _connectWithWebSocket(
  Uri uri,
  Completer<VmServiceWrapper> connectedCompleter,
  Completer<void> finishedCompleter,
) {
  // Map the URI (which may be Observatory web app) to a WebSocket URI for
  // the VM service.
  uri = convertToWebSocketUrl(serviceProtocolUrl: uri);
  final ws = WebSocket(uri.toString());

  ws.onOpen.listen((_) {
    final Stream<dynamic> inStream =
        convertBroadcastToSingleSubscriber(ws.onMessage)
            .asyncMap<dynamic>((MessageEvent e) {
      if (e.data is String) {
        return e.data;
      } else {
        final fileReader = FileReader();
        fileReader.readAsArrayBuffer(e.data);
        return fileReader.onLoadEnd.first.then<ByteData>((ProgressEvent _) {
          final Uint8List list = fileReader.result;
          return ByteData.view(list.buffer);
        });
      }
    });

    final service = VmServiceWrapper.fromNewVmService(
      inStream,
      ws.send,
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

Future<VmServiceWrapper> connect(Uri uri, Completer<void> finishedCompleter) {
  final connectedCompleter = Completer<VmServiceWrapper>();
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
