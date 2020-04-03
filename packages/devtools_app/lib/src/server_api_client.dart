// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:html';

import 'config_specific/sse/sse_shim.dart';
import 'main.dart';

class DevToolsServerApiClient {
  DevToolsServerApiClient(this._framework) : _channel = SseClient('/api/sse') {
    _channel.stream?.listen((msg) {
      try {
        final request = jsonDecode(msg);
        assert(request['method'] != null);
        switch (request['method']) {
          case 'connectToVm':
            connectToVm(request['params']);
            return;
          case 'showPage':
            showPage(request['params']);
            return;
          case 'enableNotifications':
            Notification.requestPermission();
            return;
          case 'notify':
            notify();
            return;
          default:
            print('Unknown request ${request.method} from server');
        }
      } catch (e) {
        print('Failed to handle API message from server:\n\n$msg\n\n$e');
      }
    });
  }

  final HtmlPerfToolFramework _framework;
  final SseClient _channel;
  Notification _lastNotification;

  int _nextRequestId = 0;

  void _send(String method, [Map<String, dynamic> params]) {
    final id = _nextRequestId++;
    final json = jsonEncode({'id': id, 'method': method, 'params': params});
    _channel.sink?.add(json);
  }

  void notifyConnected(Uri vmServiceUri) {
    _send('connected', {'uri': vmServiceUri.toString()});
  }

  void notifyDisconnected() {
    _send('disconnected');
  }

  void notifyCurrentPage(String pageId) {
    _send('currentPage', {'id': pageId});
  }

  void connectToVm(Map<String, dynamic> requestParams) {
    // Reload the page with the new VM service URI in the querystring.
    // TODO(dantup): Remove this code and replace with code that just reconnects
    // (and optionally notifies based on requestParams['notify']) when it's
    // supported better (https://github.com/flutter/devtools/issues/989).
    //
    // This currently doesn't currently work, as the app does not reinitialize
    // correctly:
    //
    //   _framework.connectDialog.connectTo(Uri.parse(requestParams['uri']));
    //   if (requestParams['notify'] == true) {
    //     this.notify();
    //   }
    final uri = Uri.parse(window.location.href);
    final newUriParams = Map.of(uri.queryParameters);
    newUriParams['uri'] = requestParams['uri'];
    if (requestParams['notify'] == true) {
      newUriParams['notify'] = 'true';
    }
    window.location
        .replace(uri.replace(queryParameters: newUriParams).toString());
  }

  void showPage(Map<String, dynamic> requestParams) {
    final String pageId = requestParams['page'];
    final screen = _framework.getScreen(pageId);
    if (screen != null) {
      _framework.load(screen);
    }
  }

  Future<void> notify() async {
    final permission = await Notification.requestPermission();
    if (permission != 'granted') {
      return;
    }

    // Dismiss any earlier notifications first so they don't build up
    // in the notifications list if the user presses the button multiple times.
    dismissNotifications();

    _lastNotification = Notification('Dart DevTools',
        body: 'DevTools is available in this existing browser window');
  }

  void dismissNotifications() {
    _lastNotification?.close();
  }
}
