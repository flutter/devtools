// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';

import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf;
import 'package:shelf_static/shelf_static.dart';
import 'package:sse/server/sse_handler.dart';
import 'package:usage/usage_io.dart';

import 'client_manager.dart';

/// Default [shelf.Handler] for serving DevTools files.
///
/// This serves files out from the build results of running a pub build of the
/// DevTools project.
Future<shelf.Handler> defaultHandler(ClientManager clients) async {
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

  final sseHandler = SseHandler(Uri.parse('/api/sse'))
    ..connections.rest.listen(clients.acceptClient);

  // Make a handler that delegates based on path.
  final handler = (shelf.Request request) {
    if (request.url.path.startsWith('packages/')) {
      // request.change here will strip the `packages` prefix from the path
      // so it's relative to packHandler's root.
      return packHandler(request.change(path: 'packages'));
    }

    if (request.url.path.startsWith('api/sse')) {
      return sseHandler.handler(request);
    }

    // The API handler takes all other calls to api/.
    if (ServerApi.canHandle(request)) {
      return ServerApi.handle(request);
    }

    return buildHandler(request);
  };

  return handler;
}

/// The DevTools server API.
///
/// This defines endpoints that serve all requests that come in over api/.
class ServerApi {
  /// Determines whether or not [request] is an API call.
  static bool canHandle(shelf.Request request) {
    return request.url.path.startsWith('api/');
  }

  /// Handles all requests.
  ///
  /// To override an API call, pass in a subclass of [ServerApi].
  static FutureOr<shelf.Response> handle(
    shelf.Request request, [
    ServerApi api,
  ]) {
    api ??= ServerApi();
    switch (request.url.path) {
      case 'api/logScreenView':
        return api.logScreenView(request);
      case 'api/getUserId':
        return api.getUserId(request);
      case 'analytics/getFirstRun':
        print('>>>>> analytics/getFirstRun');
        return api.getFirstRun(request);
      case 'analytics/getFirstRun':
        return api.getEnabled(request);
      case 'analytics/setEnbled':
        print('>>>>> analytics/setEnbled');
        return api.setEnabled(request);
      case 'analytics/getClientId':
        print('>>>>> analytics/getClientId');
        return api.getClientId(request);
      default:
        return api.notImplemented(request);
    }
  }

  final Usage _usage = Usage();

  /// Logs a page view in the DevTools server.
  ///
  /// In the open-source version of DevTools, Google Analytics handles this
  /// without any need to involve the server.
  FutureOr<shelf.Response> logScreenView(shelf.Request request) =>
      notImplemented(request);

  /// Gets a user's id for use in analytics and for distinguishing internal
  /// users from external users.
  ///
  /// This endpoint is not supported externally and will only be implemented for
  /// the version of DevTools used inside Google.
  FutureOr<shelf.Response> getUserId(shelf.Request request) =>
      notImplemented(request);

  /// Has Analytics dialog appeared yet - Flutter tool every used?
  FutureOr<shelf.Response> getFirstRun(shelf.Request request) =>
      shelf.Response.ok('${_usage.isFirstRun}');

  /// Has Analytics dialog appeared yet - Flutter tool every used?
  FutureOr<shelf.Response> getEnabled(shelf.Request request) =>
      shelf.Response.ok('${_usage.enabled}');

  /// Has Analytics dialog appeared yet - Flutter tool every used?
  FutureOr<shelf.Response> setEnabled(shelf.Request request) {
    _usage.enabled = true;
    shelf.Response.ok('Done');
  }

  /// Has Analytics dialog appeared yet - Flutter tool every used?
  FutureOr<shelf.Response> getClientId(shelf.Request request) =>
      shelf.Response.ok('${_usage.clientId}');

  /// A [shelf.Response] for API calls that have not been implemented in this
  /// server.
  ///
  /// This is a no-op 204 No Content response because returning 404 Not Found
  /// creates unnecessary noise in the console.
  FutureOr<shelf.Response> notImplemented(shelf.Request request) =>
      shelf.Response(204);
}

class Usage {
  Analytics _analytics;

  /// Create a new Usage instance; [versionOverride] and [configDirOverride] are
  /// used for testing.
  Usage(
      {String settingsName = 'flutter',
      String versionOverride,
      String configDirOverride}) {
    // final FlutterVersion flutterVersion = FlutterVersion.instance;
    // final String version = versionOverride ?? flutterVersion.getVersionString(redactUnknownBranches: true);
    // TODO(terry): UA, first parameter, is '' could be DevTools UA
    // TODO(terry): version, second parameter, is '' could be real Flutter version #.
    // TODO(terry): documentDirectory, third parameter, is null could be :
    //    documentDirectory: configDirOverride != null ? fs.directory(configDirOverride) : null
    _analytics = AnalyticsIO('', settingsName, '', documentDirectory: null);
  }

  bool get isFirstRun => _analytics.firstRun;

  bool get enabled => _analytics.enabled;

  set enabled(bool value) => _analytics.enabled = value;

  String get clientId => _analytics.clientId;
}
