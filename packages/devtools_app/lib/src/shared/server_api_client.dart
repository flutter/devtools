// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config_specific/logger/logger.dart';
import '../config_specific/notifications/notifications.dart';
import '../config_specific/sse/sse_shim.dart';
import 'framework_controller.dart';
import 'globals.dart';

/// This class coordinates the connection between the DevTools server and the
/// DevTools web app.
///
/// See `package:dds/src/devtools/client.dart`.
class DevToolsServerConnection {
  DevToolsServerConnection._(this.sseClient) {
    sseClient.stream!.listen((msg) {
      _handleMessage(msg);
    });
    initFrameworkController();
  }

  static Future<DevToolsServerConnection?> connect() async {
    final baseUri = Uri.base;
    // Ensure we don't drop portions of the path at which DevTools is hosted.
    final baseUriPathSegments = baseUri.pathSegments.where(
      (e) => e.isNotEmpty,
    );
    final uri = Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.port,
      pathSegments: [
        ...baseUriPathSegments,
        'api',
        'ping',
      ],
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      // When running with the local dev server Flutter may serve its index page
      // for missing files to support the hashless url strategy. Check the response
      // content to confirm it came from our server.
      // See https://github.com/flutter/flutter/issues/67053
      if (response.statusCode != 200 || response.body != 'OK') {
        // unable to locate dev server
        log('devtools server not available (${response.statusCode})');
        return null;
      }
    } catch (e) {
      // unable to locate dev server
      log('devtools server not available ($e)');
      return null;
    }

    final sseUri = Uri(
      pathSegments: [
        '', // Leading '/'
        ...baseUriPathSegments,
        'api',
        'sse'
      ],
    );
    final client = SseClient(sseUri.toString());
    return DevToolsServerConnection._(client);
  }

  final SseClient sseClient;

  int _nextRequestId = 0;
  Notification? _lastNotification;

  final Map<String, Completer> _completers = {};

  /// Tie the DevTools server connection to the framework controller.
  ///
  /// This is called once, sometime after the `DevToolsServerConnection`
  /// instance is created.
  void initFrameworkController() {
    frameworkController.onConnected.listen((vmServiceUri) {
      _notifyConnected(vmServiceUri);
    });

    frameworkController.onPageChange.listen((page) {
      _notifyCurrentPage(page);
    });

    frameworkController.onDisconnected.listen((_) {
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

  Future<T> _callMethod<T>(String method, [Map<String, dynamic>? params]) {
    final id = '${_nextRequestId++}';
    final json = jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    });
    final completer = Completer<T>();
    _completers[id] = completer;
    sseClient.sink!.add(json);
    return completer.future;
  }

  void _handleMessage(dynamic msg) {
    try {
      final Map request = jsonDecode(msg);

      if (request.containsKey('method')) {
        final String method = request['method'];
        final Map<String, dynamic> params = request['params'] ?? {};
        _handleMethod(method, params);
      } else if (request.containsKey('id')) {
        _handleResponse(request['id']!, request['result']);
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
        frameworkController.notifyConnectToVmEvent(
          Uri.parse(uri),
          notify: notify,
        );
        return;
      case 'showPage':
        final String pageId = params['page'];
        frameworkController.notifyShowPageId(pageId);
        return;
      case 'enableNotifications':
        Notification.requestPermission();
        return;
      case 'notify':
        notify();
        return;
      case 'ping':
        ping();
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

  void _notifyCurrentPage(PageChangeEvent page) {
    _callMethod(
      'currentPage',
      {
        'id': page.id,
        'embedded': page.embedded,
      },
    );
  }

  void _notifyDisconnected() {
    _callMethod('disconnected');
  }

  /// Retrieves a preference value from the DevTools configuration file at
  /// ~/.flutter-devtools/.devtools.
  Future<String> getPreferenceValue(String key) {
    return _callMethod('getPreferenceValue', {
      'key': key,
    });
  }

  /// Sets a preference value in the DevTools configuration file at
  /// ~/.flutter-devtools/.devtools.
  Future setPreferenceValue(String key, String value) async {
    await _callMethod('setPreferenceValue', {
      'key': key,
      'value': value,
    });
  }

  /// Allows the server to ping the client to see that it is definitely still
  /// active and doesn't just appear to be connected because of SSE timeouts.
  void ping() {
    _callMethod('pingResponse');
  }
}
