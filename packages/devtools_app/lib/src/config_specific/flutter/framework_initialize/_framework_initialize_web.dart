// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html';

import 'package:pedantic/pedantic.dart';

import '../../../server_api_client.dart';

/// Return the url the application is launched from.
Future<String> initializePlatform() async {
  // Clear out the unneeded HTML from index.html.
  for (var element in document.body.querySelectorAll('.legacy-dart')) {
    element.remove();
  }

  // Here, we try and initialize the connection between the DevTools web app and
  // its local server. DevTools can be launched without the server however, so
  // establishing this connection is a best-effort.
  unawaited(DevToolsServerConnection.connect());

  return '${window.location}';
}
