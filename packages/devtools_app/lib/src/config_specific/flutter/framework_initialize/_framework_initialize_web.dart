// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html';

import '../../../globals.dart';
import '../../../server_api_client.dart';
import '../../logger/logger.dart';

/// Return the url the application is launched from.
Future<String> initializePlatform() async {
  // Clear out the unneeded HTML from index.html.
  for (var element in document.body.querySelectorAll('.legacy-dart')) {
    element.remove();
  }

  // Here, we try and initialize the connection between the DevTools web app and
  // its local server. DevTools can be launched without the server however, so
  // establishing this connection is a best-effort.
  DevToolsServerConnection serverConnection;
  try {
    serverConnection = await DevToolsServerConnection.connect();
  } catch (e) {
    log('Unable connect to the devtools server: $e', LogLevel.warning);
  }

  if (serverConnection != null) {
    // Set the DevToolsServerConnection as a global; we'll later init it with
    // the FrameworkController.
    serverConnection.initFrameworkController();
  }

  return '${window.location}';
}
