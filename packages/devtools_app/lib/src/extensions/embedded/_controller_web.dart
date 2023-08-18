// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_web_libraries_in_flutter, as designed
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:devtools_extensions/api.dart';
import 'package:path/path.dart' as path;

import 'controller.dart';

/// Incrementer for the extension iFrame view that will live for the entire
/// DevTools lifecycle.
///
/// Each time [EmbeddedExtensionControllerImpl.init] is called, we create a new
/// [html.IFrameElement] and register it to
/// [EmbeddedExtensionControllerImpl.viewId] via
/// [ui_web.platformViewRegistry.registerViewFactory]. Each new
/// [html.IFrameElement] must have a unique id in the [PlatformViewRegistry],
/// which [_viewIdIncrementer] is used to create.
var _viewIdIncrementer = 0;

class EmbeddedExtensionControllerImpl extends EmbeddedExtensionController {
  EmbeddedExtensionControllerImpl(super.extensionConfig);

  /// The view id for the extension iFrame.
  ///
  /// See [_viewIdIncrementer] for an explanation of why we use an incrementer
  /// in the id.
  late final viewId = 'ext-${extensionConfig.name}-${_viewIdIncrementer++}';

  // TODO(kenz): pass along IDE theme query parameters from the DevTools URL.
  String get extensionUrl {
    return path.join(
      html.window.location.origin,
      'devtools_extensions',
      extensionConfig.name,
      'index.html',
    );
  }

  html.IFrameElement get extensionIFrame => _extensionIFrame;

  late final html.IFrameElement _extensionIFrame;

  final extensionPostEventStream =
      StreamController<DevToolsExtensionEvent>.broadcast();

  bool _initialized = false;

  @override
  void init() {
    assert(
      !_initialized,
      'EmbeddedExtensionController.init() should only be called once.',
    );
    _initialized = true;

    _extensionIFrame = html.IFrameElement()
      // This url is safe because we built it ourselves and it does not include
      // any user input.
      // ignore: unsafe_html
      ..src = extensionUrl
      ..allow = 'usb';
    _extensionIFrame.style
      ..border = 'none'
      ..height = '100%'
      ..width = '100%';

    final registered = ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) => _extensionIFrame,
    );
    assert(registered, 'Failed to register view factory for $viewId.');
  }

  @override
  void postMessage(DevToolsExtensionEventType type, String message) {
    extensionPostEventStream.add(
      DevToolsExtensionEvent(
        type,
        data: {'message': message},
      ),
    );
  }

  @override
  void dispose() async {
    await extensionPostEventStream.close();
    super.dispose();
  }
}
