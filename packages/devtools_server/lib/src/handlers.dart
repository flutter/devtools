// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';

import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf;
import 'package:shelf_static/shelf_static.dart';

/// Default [shelf.Handler] for serving DevTools files.
///
/// This serves files out from the build results of running a pub build of the
/// DevTools project.
Future<shelf.Handler> defaultHandler() async {
  final resourceUri = await Isolate.resolvePackageUri(
      Uri(scheme: 'package', path: 'devtools/devtools.dart'));
  final packageDir = path.dirname(path.dirname(resourceUri.toFilePath()));

  // Default static handler for all non-package requests.
  final buildDir = path.join(packageDir, 'build');
  final buildHandler = createStaticHandler(
    buildDir,
    defaultDocument: 'index.html',
  );

  // The packages folder is renamed in the pub package so this handler serves
  // out of the `pack` folder.
  final packagesDir = path.join(packageDir, 'build', 'pack');
  final packHandler = createStaticHandler(
    packagesDir,
    defaultDocument: 'index.html',
  );

  // Make a handler that delegates based on path.
  return (shelf.Request request) {
    // The API handler takes all calls to api/.
    if (Api.canHandle(request)) {
      return Api.handle(request);
    }
    return request.url.path.startsWith('packages/')
        // request.change here will strip the `packages` prefix from the path
        // so it's relative to packHandler's root.
        ? packHandler(request.change(path: 'packages'))
        : buildHandler(request);
  };
}

/// The DevTools server API.
///
/// This defines endpoints that serve all requests that come in over api/.
class Api {
  /// Determines whether or not [request] is an API call.
  static bool canHandle(shelf.Request request) {
    return request.url.path.startsWith('api/');
  }

  /// Handles all requests.
  ///
  /// To override an API call, pass in a subclass of [Api].
  static FutureOr<shelf.Response> handle(shelf.Request request, [Api api]) {
    api ??= Api();
    switch (request.url.path) {
      case 'api/logPageView':
        return api.logPageView(request);
      default:
        return api.notImplemented;
    }
  }

  /// Logs a page view in the DevTools server.
  ///
  /// In the open-source version of DevTools, Google Analytics handles this
  /// without any need to involve the server.
  FutureOr<shelf.Response> logPageView(shelf.Request request) async {
    return notImplemented;
  }

  /// A [shelf.Response] for API calls that have not been implemented in this
  /// server.
  shelf.Response get notImplemented => shelf.Response.notFound(
      'This API is not implemented in this version of the DevTools server.');
}
