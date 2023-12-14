// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Code needs to match API from VmService.
// ignore_for_file: avoid-dynamic

import 'dart:async';

import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../sse/sse_shim.dart';

Future<T> _connectWithSse<T extends VmService>({
  required Uri uri,
  required void Function(Object?) onError,
  required Completer<void> finishedCompleter,
  required VmServiceFactory<T> serviceFactory,
}) {
  final serviceCompleter = Completer<T>();

  uri = uri.scheme == 'sse'
      ? uri.replace(scheme: 'http')
      : uri.replace(scheme: 'https');
  final client = SseClient('$uri', debugKey: 'DevToolsService');
  final Stream<String> stream =
      client.stream!.asBroadcastStream() as Stream<String>;
  final service = serviceFactory(
    inStream: stream,
    writeMessage: client.sink!.add,
    wsUri: uri.toString(),
  );

  unawaited(
    client.sink!.done.whenComplete(() {
      finishedCompleter.complete();
      service.dispose();
    }),
  );
  serviceCompleter.complete(service);

  unawaited(stream.drain().catchError(onError));
  return serviceCompleter.future;
}

Future<T> _connectWithWebSocket<T extends VmService>({
  required Uri uri,
  required void Function(Object?) onError,
  required Completer<void> finishedCompleter,
  required VmServiceFactory<T> serviceFactory,
}) async {
  // Map the URI (which may be Observatory web app) to a WebSocket URI for
  // the VM service.
  uri = convertToWebSocketUrl(serviceProtocolUrl: uri);
  final ws = WebSocketChannel.connect(uri);
  final stream = ws.stream.handleError(onError);
  final service = serviceFactory(
    inStream: stream,
    writeMessage: (String message) {
      ws.sink.add(message);
    },
    wsUri: uri.toString(),
  );

  if (ws.closeCode != null) {
    onError(null);
    return service;
  }
  unawaited(
    ws.sink.done.then(
      (_) {
        finishedCompleter.complete();
        service.dispose();
      },
      onError: onError,
    ),
  );
  return service;
}

Future<T> connect<T extends VmService>({
  required Uri uri,
  required Completer<void> finishedCompleter,
  required VmServiceFactory<T> serviceFactory,
}) {
  final connectedCompleter = Completer<T>();

  void onError(error) {
    if (!connectedCompleter.isCompleted) {
      connectedCompleter.completeError(error);
    }
  }

  // Connects to a VM Service but does not verify the connection was fully
  // successful.
  Future<T> connectHelper() async {
    final useSse = uri.scheme == 'sse' || uri.scheme == 'sses';
    final T service = useSse
        ? await _connectWithSse<T>(
            uri: uri,
            onError: onError,
            finishedCompleter: finishedCompleter,
            serviceFactory: serviceFactory,
          )
        : await _connectWithWebSocket<T>(
            uri: uri,
            onError: onError,
            finishedCompleter: finishedCompleter,
            serviceFactory: serviceFactory,
          );
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
