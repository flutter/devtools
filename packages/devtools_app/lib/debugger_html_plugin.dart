// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This code imports dart:ui, but it uses API calls
// that are only available in the web implementation of dart:ui.
import 'dart:ui' as dart_ui_web;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

// TODO(https://github.com/flutter/devtools/issues/1258): switch to dart:html
// when turning down html_shim.
// This is web plugin code may only be compiled into the web app.
import 'package:html_shim/html.dart' as html;

import 'src/debugger/html_debugger_screen.dart';
import 'src/framework/framework_core.dart';
import 'src/framework/html_framework.dart';
import 'src/ui/html_elements.dart';

/// A web-only Flutter plugin to show the [HtmlDebuggerScreen].
class DebuggerHtmlPlugin {
  HtmlFramework _framework;
  HtmlDebuggerScreen _screen;
  html.Element _viewRoot;
  String location;

  /// Registers this plugin with Flutter.
  ///
  /// The pubspec.yaml tells Flutter to look at this class for a plugin.
  /// When it finds the class, it invokes this static method from
  /// `generated_plugin_registrant.dart`.
  static void registerWith(Registrar registrar) {
    final instance = DebuggerHtmlPlugin();
    // This call is only defined for the web implementation of dart:ui.
    // The regular dart UI cannot resolve this method call.
    // TODO(https://github.com/flutter/flutter/issues/43377): Remove 'ignore'
    // after the APIs match between flutter and web.
    // ignore:undefined_prefixed_name
    dart_ui_web.platformViewRegistry.registerViewFactory(
      'DebuggerFlutterPlugin',
      instance.build,
    );
  }

  /// Builds the html content of the debugger plugin.
  ///
  /// [viewId] is used to distinguish between multiple instances of the same
  /// view, such as video players.  We can ignore it on DevTools.
  html.Element build(int viewId) {
    Future<bool> frameworkFuture;
    // If we've changed our address, re-connect to the vm service and re-theme
    // the view.
    // We replace the #/ with a / so that dart can parse the uri query parameters
    // as query parameters.
    final location = html.window.location.toString().replaceFirst('#/', '/');
    if (location != this.location) {
      this.location = location;
      // TODO(djshuckerow): investigate why we need to reinitialize globals
      // in release mode when they already exist.
      FrameworkCore.init(location);
      frameworkFuture = FrameworkCore.initVmService(
        location,
        errorReporter: (message, __) {
          print(message);
        },
      );
    }
    if (_viewRoot != null) {
      return _viewRoot;
    }
    // Flutter loads this view inside of a shadow DOM.
    // To get our existing CSS to work, we wrap the shadow page with the regular
    //
    // <html><head></head><body></body></html>.
    _viewRoot = html.Element.tag('html');
    Future(() async {
      final debuggerHtml =
          await html.HttpRequest.getString('debugger_screen.html');
      await frameworkFuture;
      _updateViewRoot(debuggerHtml);
    });
    return _viewRoot;
  }

  /// Loads the [HtmlDebuggerScreen] after receiving the debugger screen
  /// template html.
  void _updateViewRoot(String response) {
    _viewRoot.setInnerHtml(
      response,
      treeSanitizer: html.NodeTreeSanitizer.trusted,
    );

    // Tell the DevTools html code that the root to query for elements from
    // is under this overridden root.
    overrideDocumentRoot = _viewRoot;
    _framework = HtmlFramework();
    _screen = HtmlDebuggerScreen();
    _framework.addScreen(_screen);

    // Wait for the content to attach to the page, then load the debugger
    // screen.
    final observer = html.MutationObserver((mutations, observer) {
      if (_framework.mainElement.element.isConnected) {
        observer.disconnect();
        _framework.load(_screen);
      }
    });
    observer.observe(html.document, subtree: true, childList: true);

    // TODO(https://github.com/flutter/flutter/issues/43520): This works around
    // Flutter taking the mouse wheel events.
    _viewRoot.onWheel.listen((event) {
      event.stopImmediatePropagation();
    });
    _viewRoot.onMouseWheel.listen((event) {
      event.stopImmediatePropagation();
    });
  }
}
