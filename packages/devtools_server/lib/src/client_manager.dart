// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:sse/server/sse_handler.dart';

class ClientManager {
  final List<DevToolsClient> _clients = [];
  void acceptClient(SseConnection connection) {
    final client = DevToolsClient(connection);
    _clients.add(client);
    connection.sink.done.then((_) => _clients.remove(client));
  }

  List<DevToolsClient> get connectedClients => _clients.toList();

  /// Finds an active DevTools instance that is not already connecting to
  /// a VM service that we can reuse (for example if a user stopped debugging
  /// and it disconnected, then started debugging again, we want to reuse
  /// the open DevTools window).
  DevToolsClient findReusableClient() {
    return _clients.firstWhere((c) => !c.hasConnection, orElse: () => null);
  }

  /// Finds a client that may already be connected to this VM Service.
  DevToolsClient findExistingConnectedClient(Uri vmServiceUri) {
    // Checking the whole URI will fail if DevTools converted it from HTTP to
    // WS, so just check the host, port and first segment of path (token).
    return _clients.firstWhere(
        (c) =>
            c.hasConnection && _areSameVmServices(c.vmServiceUri, vmServiceUri),
        orElse: () => null);
  }

  bool _areSameVmServices(Uri uri1, Uri uri2) {
    return uri1.host == uri2.host &&
        uri1.port == uri2.port &&
        uri1.pathSegments.isNotEmpty &&
        uri2.pathSegments.isNotEmpty &&
        uri1.pathSegments[0] == uri2.pathSegments[0];
  }
}

class DevToolsClient {
  DevToolsClient(this._connection) {
    _connection.stream.listen((msg) {
      try {
        final request = jsonDecode(msg);
        switch (request['method']) {
          case 'connected':
            _vmServiceUri = Uri.parse(request['params']['uri']);
            return;
          case 'disconnected':
            _vmServiceUri = null;
            return;
          default:
            print('Unknown request ${request['method']} from client');
        }
      } catch (e) {
        print('Failed to handle API message from client:\n\n$msg\n\n$e');
      }
    });
  }

  Future<void> connectToVmService(Uri uri, bool notifyUser) async {
    _connection.sink.add(jsonEncode({
      'method': 'connectToVm',
      'params': {
        'uri': uri.toString(),
        'notify': notifyUser,
      },
    }));
  }

  Future<void> notify() async {
    _connection.sink.add(jsonEncode({
      'method': 'notify',
    }));
  }

  final SseConnection _connection;
  Uri _vmServiceUri;
  Uri get vmServiceUri => _vmServiceUri;
  bool get hasConnection => _vmServiceUri != null;
}
