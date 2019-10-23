// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// We actually use dart:html here, no shim.
// This code may only be compiled into the web app.
import 'dart:ui' as web_ui;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:html_shim/html.dart' as html;

import 'src/debugger/html_debugger_screen.dart';
import 'src/ui/html_elements.dart';

/// Debugger HTML view.
///
/// This is code that will run as a web-only Flutter plugin.
class DebuggerHtmlPlugin {
  DebuggerHtmlPlugin();

  static void registerWith(Registrar registrar) {
    final instance = DebuggerHtmlPlugin();
    // ignore:undefined_prefixed_name
    web_ui.platformViewRegistry
        .registerViewFactory('DebuggerFlutterPlugin', instance.build);
  }

  /// Builds the html content of the debugger plugin.
  ///
  /// [viewId] is used to distinguish between multiple instances of the same
  /// view, such as video players.  We can ignore it on DevTools.
  html.Element build(int viewId) {
    return html.IFrameElement()
      ..src = 'debugger_screen.html'
      ..style.border = '0';
    print('Building html framework');
    // final framework = HtmlFramework();
    print('Built framework, building screen.');
    final screen = HtmlDebuggerScreen();
    print('Building html contents');
    final element = screen.createContent(null);
    print('Element: ${element.element}');
    element.attribute('full');
    final div = html.DivElement();
    html.HttpRequest.getString('debugger_screen.html').then((response) {
      final fullContent = html.Element.html(response);
      final content = fullContent.querySelector('#content')
        ..children.clear()
        ..children.add(element.element);

      div.replaceWith(content);
    });
    return div;
  }
}
