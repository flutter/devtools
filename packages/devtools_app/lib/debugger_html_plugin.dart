// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// We actually use dart:html here, no shim.
// This code may only be compiled into the web app.
import 'dart:ui' as web_ui;

import 'package:devtools_app/src/ui/html_elements.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:html_shim/html.dart' as html;

import 'src/debugger/html_debugger_screen.dart';
import 'src/framework/html_framework.dart';

/// Debugger HTML view.
///
/// This is code that will run as a web-only Flutter plugin.
class DebuggerHtmlPlugin {
  DebuggerHtmlPlugin();

  HtmlFramework _framework;
  HtmlDebuggerScreen _screen;
  html.Element _viewRoot;

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
    if (_viewRoot != null) {
      return _viewRoot;
    }
    _viewRoot = html.Element.tag('html');
    html.HttpRequest.getString('debugger_screen.html').then((response) {
      _viewRoot.setInnerHtml(
        response,
        treeSanitizer: html.NodeTreeSanitizer.trusted,
      );

      overrideDocumentRoot = _viewRoot;
      print('Building html framework');
      _framework = HtmlFramework();
      print('Built framework, building screen.');
      _screen = HtmlDebuggerScreen();
      _framework.addScreen(_screen);
      final observer = html.MutationObserver((mutations, observer) {
        if (_framework.mainElement.element.isConnected) {
          observer.disconnect();
          _framework.load(_screen);
        }
      });
      observer.observe(html.document, subtree: true, childList: true);
    });
    print('returning div');
    return _viewRoot;
  }

  /// Handles requests from Flutter of this view.
  ///
  /// Currently there is no API for interaction between the views,
  /// so it supports no methods.
  Future<dynamic> handleMethodCall(MethodCall call) async {}
}
