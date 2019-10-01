// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:html';

import 'package:sse/client/sse_client.dart';

class DevToolsServerApiClient {
  DevToolsServerApiClient() : _channel = SseClient('/api/sse') {
    _channel.stream.listen((msg) {
      try {
        final request = jsonDecode(msg);
        assert(request['method'] != null);
        switch (request['method']) {
          case 'connectToVm':
            connectToVm(request['params']);
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

  final SseClient _channel;

  int _nextRequestId = 0;
  void _send(String method, [Map<String, dynamic> params]) {
    final id = _nextRequestId++;
    final json = jsonEncode({'id': id, 'method': method, 'params': params});
    _channel.sink.add(json);
  }

  void notifyConnected(Uri vmServiceUri) {
    _send('connected', {'uri': vmServiceUri.toString()});
  }

  void notifyDisconnected() {
    _send('disconnected');
  }

  void connectToVm(dynamic requestParams) {
    // Reload the page with the new VM service URI in the querystring.
    // TODO(dantup): Remove this code and replace with code that just reconnects
    // (and optionall notifies based on requestParams['notify']) when it's
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

  Future<void> notify() async {
    final permission = await Notification.requestPermission();
    if (permission != 'granted') {
      return;
    }

    Notification('Dart DevTools',
        body: 'DevTools is available in this existing browser window');
  }
}
