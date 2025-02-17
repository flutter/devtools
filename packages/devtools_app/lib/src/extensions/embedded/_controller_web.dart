// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:ui_web' as ui_web;

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_extensions/api.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:path/path.dart' as path;
import 'package:web/web.dart';

import '../../shared/development_helpers.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/query_parameters.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/server/server.dart';
import '../../shared/utils/utils.dart';
import 'controller.dart';

/// Incrementer for the extension iFrame view that will live for the entire
/// DevTools lifecycle.
///
/// Each time [EmbeddedExtensionControllerImpl.init] is called, we create a new
/// [HTMLIFrameElement] and register it to
/// [EmbeddedExtensionControllerImpl.viewId] via
/// `ui_web.platformViewRegistry.registerViewFactory`. Each new
/// [HTMLIFrameElement] must have a unique id in the
/// [ui_web.PlatformViewRegistry], which [_viewIdIncrementer] is used to create.
var _viewIdIncrementer = 0;

class EmbeddedExtensionControllerImpl extends EmbeddedExtensionController
    with AutoDisposeControllerMixin {
  EmbeddedExtensionControllerImpl(super.extensionConfig);

  /// The view id for the extension iFrame.
  ///
  /// See [_viewIdIncrementer] for an explanation of why we use an incrementer
  /// in the id.
  late final viewId = 'ext-${extensionConfig.name}-${_viewIdIncrementer++}';

  String get extensionUrl {
    if (debugDevToolsExtensions && !isDevToolsServerAvailable) {
      return 'https://flutter.dev/';
    }

    final basePath = devtoolsAssetsBasePath(
      // This needs to use the DevTools server URI as the origin because the
      // extension assets are served through a DevTools server handler. The
      // DevTools server handler loads them directly from their location in the
      // user's pub-cache.
      origin: devToolsServerUriAsString,
      path: window.location.pathname,
    );
    final baseUri = path.join(
      basePath,
      extensionRequestPath,
      extensionConfig.identifier,
      'index.html',
    );
    final queryParams = {
      ...DevToolsQueryParams.load().params,
      ExtensionEventParameters.theme:
          isDarkThemeEnabled()
              ? ExtensionEventParameters.themeValueDark
              : ExtensionEventParameters.themeValueLight,
      if (dtdManager.uri != null) 'dtdUri': dtdManager.uri.toString(),
    };
    return Uri.parse(baseUri).replace(queryParameters: queryParams).toString();
  }

  HTMLIFrameElement get extensionIFrame => _extensionIFrame;

  late final HTMLIFrameElement _extensionIFrame;

  /// A stream of [DevToolsExtensionEvent]s that will be posted from the
  /// DevTools web app to the embedded extension iFrame.
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

    _extensionIFrame =
        HTMLIFrameElement()
          // This url is safe because we built it ourselves and it does not include
          // any user input.
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
  void postMessage(
    DevToolsExtensionEventType type, {
    Map<String, String> data = const <String, String>{},
  }) {
    extensionPostEventStream.add(DevToolsExtensionEvent(type, data: data));
  }

  @override
  void dispose() async {
    await extensionPostEventStream.close();
    super.dispose();
  }
}
