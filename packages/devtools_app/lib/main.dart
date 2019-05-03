// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:html_shim/html.dart' show document, window;

import 'src/flutter/app.dart';
import 'src/framework/framework_core.dart';

void main() {
  String url;
  ;
  if (kIsWeb) {
    // Clear out the unneeded HTML from index.html.
    for (var element in document.body.querySelectorAll('.legacy-dart')) {
      element.remove();
    }
    url = window.location.toString();
  } else {
    // When running in a desktop embedder, Flutter throws an error because the
    // platform is not officially supported. This is not needed for web.
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    // TODO(jacobr): we don't yet have a direct analog to the URL on flutter
    // desktop.
    // Hard code to the dark theme as the majority of users are on the dark
    // theme.
    url = 'http://127.0.0.1/?theme=dark';
  }
  FrameworkCore.init(url);

  // Now run the app.
  runApp(
    DevToolsApp(),
  );
}
