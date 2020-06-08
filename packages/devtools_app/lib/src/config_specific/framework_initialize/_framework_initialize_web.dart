// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' hide Storage;

import '../../globals.dart';
import '../../server_api_client.dart';
import '../../storage.dart';

/// Return the url the application is launched from.
Future<String> initializePlatform() async {
  // Clear out the unneeded HTML from index.html.
  for (var element in document.body.querySelectorAll('.legacy-dart')) {
    element.remove();
  }

  // Here, we try and initialize the connection between the DevTools web app and
  // its local server. DevTools can be launched without the server however, so
  // establishing this connection is a best-effort.
  final connection = await DevToolsServerConnection.connect();
  if (connection != null) {
    setGlobal(Storage, ServerConnectionStorage(connection));
  } else {
    setGlobal(Storage, BrowserStorage());
  }

  // Prevent the browser default behavior for specific keybindings we'll later
  // handle in the app. This is a workaround for
  // https://github.com/flutter/flutter/issues/58119.
  window.onKeyDown.listen((event) {
    // Here, we're just trying to match the '⌘P' keybinding on macos.
    if (!event.metaKey) {
      return;
    }
    if (!window.navigator.userAgent.contains('Macintosh')) {
      return;
    }

    if (event.key == 'p') {
      event.preventDefault();
    }
  });

  return '${window.location}';
}

class ServerConnectionStorage implements Storage {
  ServerConnectionStorage(this.connection);

  final DevToolsServerConnection connection;

  @override
  Future<String> getValue(String key) async {
    return connection.getPreferenceValue(key);
  }

  @override
  Future setValue(String key, String value) async {
    await connection.setPreferenceValue(key, value);
  }
}

class BrowserStorage implements Storage {
  @override
  Future<String> getValue(String key) async {
    return window.localStorage[key];
  }

  @override
  Future setValue(String key, String value) async {
    window.localStorage[key] = value;
  }
}
