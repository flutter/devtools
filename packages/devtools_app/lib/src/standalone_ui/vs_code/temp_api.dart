// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc_2;
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../shared/config_specific/post_message/post_message.dart';

// TODO(dantup): This should live in a package so it can be used by tools
//  hosted outside of DevTools.

/// An API for interacting with Dart tooling.
class DartApi {
  DartApi._(this._rpc) : vsCode = VsCodeApi(_rpc) {
    unawaited(_rpc.listen());
  }

  /// Connects the API using 'postMessage'. This is only available when running
  /// on web and embedded inside VS Code.
  factory DartApi.postMessage() {
    final postMessageController = StreamController();
    postMessageController.stream.listen((message) => postMessage(message, '*'));
    final channel = StreamChannel(
      onPostMessage.map((event) => event.data),
      postMessageController,
    );
    return DartApi._(json_rpc_2.Peer.withoutJson(channel));
  }

  /// Connects the API over the provided WebSocket.
  factory DartApi.webSocket(WebSocketChannel socket) {
    return DartApi._(json_rpc_2.Peer(socket.cast<String>()));
  }

  final json_rpc_2.Peer _rpc;

  /// Access to APIs related to VS Code, such as executing VS Code commands or
  /// interacting with the Dart/Flutter extensions.
  final VsCodeApi vsCode;

  void dispose() {
    unawaited(_rpc.close());
  }
}

/// Base class for the different APIs that may be available.
abstract base class ToolApi {
  ToolApi(this.rpc);

  final json_rpc_2.Peer rpc;

  String get apiName;

  /// Checks whether this API is available.
  ///
  /// Calls to any other API should only be made if and when this [Future]
  /// completes with `true`.
  late final Future<bool> isAvailable =
      _sendRequest<bool>('checkAvailable').catchError((_) => false);

  Future<T> _sendRequest<T>(String method, [Object? parameters]) async {
    return (await rpc.sendRequest('$apiName.$method', parameters)) as T;
  }

  /// Listens for an event '[apiName].[name]' that has a Map for parameters.
  Stream<Map<String, Object?>> events(String name) {
    final streamController = StreamController<Map<String, Object?>>.broadcast();
    rpc.registerMethod('$apiName.$name', (json_rpc_2.Parameters parameters) {
      streamController.add(parameters.asMap.cast<String, Object?>());
    });
    return streamController.stream;
  }
}

final class VsCodeApi extends ToolApi {
  VsCodeApi(super.rpc);

  @override
  final apiName = 'vsCode';

  Future<Object?> getSelectedDevice() => _sendRequest('getSelectedDevice');

  Future<Object?> showDeviceSelector() =>
      executeCommand('flutter.selectDevice');

  late final Stream<Map<String, Object?>> selectedDeviceChanged =
      events('selectedDeviceChanged');

  Future<Object?> executeCommand(String command, [List<Object?>? arguments]) =>
      _sendRequest(
        'executeCommand',
        {'command': command, 'arguments': arguments},
      );
}
