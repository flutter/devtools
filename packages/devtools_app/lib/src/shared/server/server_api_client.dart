// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../config_specific/notifications/notifications.dart';
import '../framework_controller.dart';
import '../globals.dart';

final _log = Logger('lib/src/shared/server_api_client');

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

  /// Returns a URI for the backend ./api folder for a DevTools page being hosted
  /// at `baseUri`. Trailing slashes are important to support Path-URL Strategy:
  ///
  /// - http://foo/devtools/ => http://foo/devtools/api
  /// - http://foo/devtools/inspector => http://foo/devtools/api
  ///
  /// For compatibility with any tools that might construct URIs ending with
  /// "/devtools" without the trailing slash, URIs ending with `devtools` (such
  /// as when hosted by DDS) are handled specially:
  ///
  /// - http://foo/devtools => http://foo/devtools/api
  @visibleForTesting
  static Uri apiUriFor(Uri baseUri) => baseUri.path.endsWith('devtools')
      ? baseUri.resolve('devtools/api/')
      : baseUri.resolve('api/');

  static Future<DevToolsServerConnection?> connect() async {
    final apiUri = apiUriFor(Uri.base);
    final pingUri = apiUri.resolve('ping');

    try {
      final response =
          await http.get(pingUri).timeout(const Duration(seconds: 5));
      // When running with the local dev server Flutter may serve its index page
      // for missing files to support the hashless url strategy. Check the response
      // content to confirm it came from our server.
      // See https://github.com/flutter/flutter/issues/67053
      if (response.statusCode != 200 || response.body != 'OK') {
        // unable to locate dev server
        _log.info('devtools server not available (${response.statusCode})');
        return null;
      }
    } catch (e) {
      // unable to locate dev server
      _log.info('devtools server not available ($e)');
      return null;
    }

    final sseUri = apiUri.resolve('sse');
    final client = SseClient(sseUri.toString(), debugKey: 'DevToolsServer');
    return DevToolsServerConnection._(client);
  }

  final SseClient sseClient;

  int _nextRequestId = 0;
  Notification? _lastNotification;

  final _completers = <String, Completer<Object?>>{};

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

  void _handleMessage(String msg) {
    try {
      final Map request = jsonDecode(msg);

      if (request.containsKey('method')) {
        final String method = request['method'];
        final Map<String, dynamic> params = request['params'] ?? {};
        _handleMethod(method, params);
      } else if (request.containsKey('id')) {
        _handleResponse(request['id']!, request['result']);
      } else {
        _log.info('Unable to parse API message from server:\n\n$msg');
      }
    } catch (e) {
      _log.info('Failed to handle API message from server:\n\n$msg\n\n$e');
    }
  }

  void _handleMethod(String method, Map<String, dynamic> params) {
    switch (method) {
      case 'connectToVm':
        final String uri = params['uri'];
        final notify = params['notify'] == true;
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
        unawaited(Notification.requestPermission());
        return;
      case 'notify':
        unawaited(notify());
        return;
      case 'ping':
        ping();
        return;
      default:
        _log.info('Unknown request $method from server');
    }
  }

  void _handleResponse(String id, Object? result) {
    final completer = _completers.remove(id);
    completer?.complete(result);
  }

  void _notifyConnected(String vmServiceUri) {
    unawaited(_callMethod('connected', {'uri': vmServiceUri}));
  }

  void _notifyCurrentPage(PageChangeEvent page) {
    unawaited(
      _callMethod(
        'currentPage',
        {
          'id': page.id,
          // TODO(kenz): see if we need to change the client code on the
          // DevTools server to be aware of the type of embedded mode (many vs.
          // one).
          'embedded': page.embedMode.embedded,
        },
      ),
    );
  }

  void _notifyDisconnected() {
    unawaited(_callMethod('disconnected'));
  }

  /// Retrieves a preference value from the DevTools configuration file at
  /// ~/.flutter-devtools/.devtools.
  Future<String?> getPreferenceValue(String key) {
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
    unawaited(_callMethod('pingResponse'));
  }
}
