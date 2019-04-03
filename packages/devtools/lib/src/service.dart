// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' hide Event;
import 'dart:typed_data';

import 'vm_service_wrapper.dart';

Future<VmServiceWrapper> connect(Uri uri, Completer<Null> finishedCompleter) {
  final WebSocket ws = WebSocket(uri.toString());

  final Completer<VmServiceWrapper> connectedCompleter =
      Completer<VmServiceWrapper>();

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
    //_logger.fine('Unable to connect to observatory, port ${port}', e);
    if (!connectedCompleter.isCompleted) {
      connectedCompleter.completeError(e);
    }
  });

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
