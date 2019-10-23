// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// We actually use dart:html here, no shim.
// This code may only be compiled into the web app.
import 'dart:html' as html;

import 'dart:ui' as web_ui;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Debugger HTML view.
///
/// This is code that will run as a web-only Flutter plugin.
class DebuggerHtmlPlugin {
  static void registerWith(Registrar registrar) {
    // ignore:undefined_prefixed_name
    web_ui.platformViewRegistry
        .registerViewFactory('DebuggerFlutterPlugin', build);
  }

  /// Builds the html content of the debugger plugin.
  ///
  /// [viewId] is used to distinguish between multiple instances of the same
  /// view, such as video players.  We can ignore it on DevTools.
  static html.Element build(int viewId) {
    return html.DivElement()..text = 'Hello world!';
  }
}
