// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'package:http/http.dart' as http;

import 'config_specific/logger/logger.dart';
import 'config_specific/sse/sse_shim.dart';

// TODO(devoncarew): make sure the flutter web client sends the events:
//   connected, currentPage, disconnected

/// This class coordinates the connection between the DevTools server and the
/// DevTools web app.
///
/// See `packages/devtools_server/lib/src/client_manager.dart`.
class DevToolsServerConnection {
  DevToolsServerConnection._(this.sseClient) {
    sseClient.stream.listen((msg) {
      _handleMessage(msg);
    });
  }

  static Future<DevToolsServerConnection> connect() async {
    final baseUri = Uri.base;
    final uri = Uri(
        scheme: baseUri.scheme,
        host: baseUri.host,
        port: baseUri.port,
        path: '/api/ping');

    try {
      // ignore: unused_local_variable
      final response = await http.get(uri).timeout(const Duration(seconds: 1));
    } catch (e) {
      // unable to locate dev server
      log('devtools server not available ($e)');
      return null;
    }

    final client = SseClient('/api/sse');

    return DevToolsServerConnection._(client);
  }

  final SseClient sseClient;

  FrameworkController _frameworkController;
  int _nextRequestId = 0;
  Notification _lastNotification;

  final Map<String, Completer> _completers = {};

  /// Install the framework controller for a particular version of the framework
  /// (dart web, flutter web). This is called once, sometime after the
  /// `DevToolsServerConnection` instance is created.
  void setFrameworkController(FrameworkController controller) {
    _frameworkController = controller;

    controller.onConnected.listen((vmServiceUri) {
      _notifyConnected(vmServiceUri);
    });

    controller.onPageChange.listen((pageId) {
      _notifyCurrentPage(pageId);
    });

    controller.onDisconnected.listen((_) {
      _notifyDisconnected();
    });
  }

  Future<void> notify() async {
    final permission = await Notification.requestPermission();
    if (permission != 'granted') {
      return;
    }

    // Dismiss any earlier notifications first so they don't build up in the
    // notifications list if the user presses the button multiple times.
    dismissNotifications();

    _lastNotification = Notification(
      'Dart DevTools',
      body: 'DevTools is available in this existing browser window',
    );
  }

  void dismissNotifications() {
    _lastNotification?.close();
  }

  Future<T> _callMethod<T>(String method, [Map<String, dynamic> params]) {
    final id = '${_nextRequestId++}';
    final json = jsonEncode({'id': id, 'method': method, 'params': params});
    final completer = Completer<T>();
    _completers[id] = completer;
    sseClient.sink.add(json);
    return completer.future;
  }

  void _handleMessage(dynamic msg) {
    try {
      final Map request = jsonDecode(msg);

      if (request.containsKey('method')) {
        final String method = request['method'];
        final Map<String, dynamic> params = request['params'];
        _handleMethod(method, params);
      } else if (request.containsKey('id')) {
        _handleResponse(request['id'], request['result']);
      } else {
        print('Unable to parse API message from server:\n\n$msg');
      }
    } catch (e) {
      print('Failed to handle API message from server:\n\n$msg\n\n$e');
    }
  }

  void _handleMethod(String method, Map<String, dynamic> params) {
    switch (method) {
      case 'connectToVm':
        final String uri = params['uri'];
        final bool notify = params['notify'] == true;
        _frameworkController.connectToVm(Uri.parse(uri), notify: notify);
        return;
      case 'showPage':
        final String pageId = params['page'];
        _frameworkController.showPageId(pageId);
        return;
      case 'enableNotifications':
        Notification.requestPermission();
        return;
      case 'notify':
        notify();
        return;
      default:
        print('Unknown request $method from server');
    }
  }

  void _handleResponse(String id, dynamic result) {
    final completer = _completers.remove(id);
    completer?.complete(result);
  }

  void _notifyConnected(Uri vmServiceUri) {
    _callMethod('connected', {'uri': vmServiceUri.toString()});
  }

  void _notifyCurrentPage(String pageId) {
    _callMethod('currentPage', {'id': pageId});
  }

  void _notifyDisconnected() {
    _callMethod('disconnected');
  }

  Future<String> getPreferenceValue(String key) {
    return _callMethod('getPreferenceValue', {
      'key': key,
    });
  }

  Future setPreferenceValue(String key, String value) async {
    await _callMethod('setPreferenceValue', {
      'key': key,
      'value': value,
    });
  }
}

/// This controller is used by the connection to the DevTools server to receive
/// commands from the server, and to notify the server of DevTools state changes
/// (page changes and device connection status changes).
abstract class FrameworkController {
  /// Show the indicated page.
  void showPageId(String pageId);

  /// Tell DevTools to connect to the app at the given VM service protocol URI.
  void connectToVm(Uri serviceProtocolUri, {bool notify = false});

  /// Notifies when DevTools connects to a device.
  ///
  /// The returned URI value is the VM service protocol URI of the device
  /// connection.
  Stream<Uri> get onConnected;

  /// Notifies when the current page changes.
  ///
  /// This notifies with the page ID.
  Stream<String> get onPageChange;

  /// Notifies when a device disconnects from DevTools.
  Stream get onDisconnected;
}
