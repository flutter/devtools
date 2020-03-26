// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' hide Storage;

import '../../../globals.dart';
import '../../../server_connection.dart';
import '../../../storage.dart';
import '../../logger/logger.dart';

/// Perform platform-specific initialization.
Future initializePlatform() async {
  // Clear out the unneeded HTML from index.html.
  for (var element in document.body.querySelectorAll('.legacy-dart')) {
    element.remove();
  }

  // Here, we try and initialize the connection between the DevTools web app and
  // its local server. DevTools can be launched without the server however, so
  // establishing this connection is a best-effort.
  DevToolsServerConnection connection;
  try {
    connection = await DevToolsServerConnection.connect();
  } catch (e) {
    log('Unable connect to the devtools server: $e', LogLevel.warning);
  }

  if (connection != null) {
    // Set the DevToolsServerConnection as a global; we'll later init it with a
    // controller for the app (setFrameworkController()).
    setGlobal(DevToolsServerConnection, connection);

    setGlobal(Storage, ServerConnectionStorage(connection));

    // TODO(devoncarew): Init the connection with our connection controller.

  } else {
    setGlobal(Storage, BrowserStorage());
  }
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
