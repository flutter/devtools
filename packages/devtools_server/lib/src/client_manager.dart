// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:sse/server/sse_handler.dart';

import 'server_api.dart';

const _verbose = false;

void _log(String message) {
  if (_verbose) {
    print('[client_manager] $message');
  }
}

/// A connection between a DevTools front-end app and the DevTools server.
///
/// see `packages/devtools_app/lib/src/server_connection.dart`.
class ClientManager {
  ClientManager(this.requestNotificationPermissions);

  /// Whether to immediately request notification permissions when a client connects.
  /// Otherwise permission will be requested only with the first notification.
  final bool requestNotificationPermissions;
  final List<DevToolsClient> _clients = [];

  List<DevToolsClient> get allClients => _clients.toList();

  void acceptClient(SseConnection connection) {
    _log('accepting new client connection: $connection');

    final client = DevToolsClient(connection);
    if (requestNotificationPermissions) {
      client.enableNotifications();
    }
    _clients.add(client);
    connection.sink.done.then((_) => _clients.remove(client));
  }

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
      _handleMessage(msg);
    });
  }

  void _handleMessage(dynamic message) {
    _log('receive: $message');

    try {
      final Map<String, dynamic> request = jsonDecode(message);
      switch (request['method']) {
        case 'connected':
          _vmServiceUri = Uri.parse(request['params']['uri']);
          _respond(request);
          return;
        case 'currentPage':
          _currentPage = request['params']['id'];
          _respond(request);
          return;
        case 'disconnected':
          _vmServiceUri = null;
          _respond(request);
          return;
        case 'getPreferenceValue':
          final String key = request['params']['key'];
          final dynamic value = ServerApi.devToolsPreferences.properties[key];
          _respondWithResult(request, value);
          return;
        case 'setPreferenceValue':
          final String key = request['params']['key'];
          final dynamic value = request['params']['value'];
          ServerApi.devToolsPreferences.properties[key] = value;
          _respond(request);
          return;
        default:
          print('Unknown request ${request['method']} from client');
      }
    } catch (e) {
      print('Failed to handle API message from client:\n\n$message\n\n$e');
    }
  }

  Future<void> connectToVmService(Uri uri, bool notifyUser) async {
    _send({
      'method': 'connectToVm',
      'params': {
        'uri': uri.toString(),
        'notify': notifyUser,
      },
    });
  }

  Future<void> notify() async {
    _send({
      'method': 'notify',
    });
  }

  Future<void> enableNotifications() async {
    _send({
      'method': 'enableNotifications',
    });
  }

  Future<void> showPage(String pageId) async {
    _send({
      'method': 'showPage',
      'params': {'page': pageId}
    });
  }

  void _send(Map<String, dynamic> message) {
    _log('send: $message');

    _connection.sink.add(jsonEncode(message));
  }

  void _respond(Map<String, dynamic> request) {
    final String id = request['id'];
    _send({
      'id': id,
    });
  }

  void _respondWithResult(Map<String, dynamic> request, dynamic result) {
    final String id = request['id'];
    final Map<String, dynamic> message = {
      'id': id,
      'result': result,
    };
    _send(message);
  }

  final SseConnection _connection;
  Uri _vmServiceUri;

  Uri get vmServiceUri => _vmServiceUri;

  bool get hasConnection => _vmServiceUri != null;
  String _currentPage;

  String get currentPage => _currentPage;
}
