// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:pedantic/pedantic.dart';
import 'package:vm_service/utils.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config_specific/sse/sse_shim.dart';
import 'vm_service_wrapper.dart';

Future<VmServiceWrapper> _connectWithSse(
  Uri uri,
  void onError(error),
  Completer<void> finishedCompleter,
) async {
  final serviceCompleter = Completer<VmServiceWrapper>();

  uri = uri.scheme == 'sse'
      ? uri.replace(scheme: 'http')
      : uri.replace(scheme: 'https');
  final client = SseClient('$uri');
  final Stream<String> stream = client.stream?.asBroadcastStream();
  client.onOpen?.listen((_) {
    final service = VmServiceWrapper.fromNewVmService(
      stream,
      client.sink.add,
      uri,
    );

    client.sink?.done?.whenComplete(() {
      finishedCompleter.complete();
      service.dispose();
    });
    serviceCompleter.complete(service);
  });

  unawaited(stream?.drain()?.catchError(onError));
  return serviceCompleter.future;
}

Future<VmServiceWrapper> _connectWithWebSocket(
  Uri uri,
  void onError(error),
  Completer<void> finishedCompleter,
) async {
  // Map the URI (which may be Observatory web app) to a WebSocket URI for
  // the VM service.
  uri = convertToWebSocketUrl(serviceProtocolUrl: uri);
  final ws = WebSocketChannel.connect(uri);
  final stream = ws.stream.handleError(onError);
  final service = VmServiceWrapper.fromNewVmService(
    stream,
    (String message) {
      ws.sink.add(message);
    },
    uri,
  );

  if (ws.closeCode != null) {
    onError(null);
    return service;
  }
  unawaited(ws.sink.done.then((_) {
    finishedCompleter.complete();
    service.dispose();
  }, onError: onError));
  return service;
}

Future<VmServiceWrapper> connect(Uri uri, Completer<void> finishedCompleter) {
  final connectedCompleter = Completer<VmServiceWrapper>();

  void onError(error) {
    if (!connectedCompleter.isCompleted) {
      connectedCompleter.completeError(error);
    }
  }

  // Connects to a VM Service but does not verify the connection was fully
  // successful.
  Future<VmServiceWrapper> connectHelper() async {
    VmServiceWrapper service;
    if (uri.scheme == 'sse' || uri.scheme == 'sses') {
      service = await _connectWithSse(uri, onError, finishedCompleter);
    } else {
      service = await _connectWithWebSocket(uri, onError, finishedCompleter);
    }
    // Verify that the VM is alive enough to actually get the version before
    // considering it successfully connected. Otherwise, VMService instances
    // that failed part way through the connection may appear to be connected.
    await service.getVersion();
    return service;
  }

  connectHelper().then(
    (service) {
      if (!connectedCompleter.isCompleted) {
        connectedCompleter.complete(service);
      }
    },
    onError: onError,
  );
  finishedCompleter.future.then((_) {
    // It is an error if we finish before we are connected.
    if (!connectedCompleter.isCompleted) {
      onError(null);
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
