// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:html_shim/html.dart' show document;

import 'src/flutter/app.dart';

void main() {
  if (kIsWeb) {
    // Clear out the unneeded HTML from index.html.
    document.body.querySelector('#legacy-dart').innerHtml = '';
  } else {
    // When running in a desktop embedder, Flutter throws an error because the
    // platform is not officially supported. This is not needed for web.
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  }
  // Now run the app.
  runApp(
    DevToolsApp(),
  );
}
