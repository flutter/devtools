// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf;
import 'package:shelf_proxy/shelf_proxy.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:sse/server/sse_handler.dart';

import 'client_manager.dart';
import 'usage.dart';

// DO NOT IMPORT THIS FILE into any files other than `devtools_server.dart`.
// This file is overwritten for internal DevTools builds, so any file depending
// on `external_handlers.dart` would break internally.

/// Default [shelf.Handler] for serving DevTools files.
///
/// This serves files out from the build results of running a pub build of the
/// DevTools project.
Future<shelf.Handler> defaultHandler(
  ClientManager clients, {
  bool debugMode = false,
}) async {
  final resourceUri = await Isolate.resolvePackageUri(
      Uri(scheme: 'package', path: 'devtools/devtools.dart'));

  final packageDir = path.dirname(path.dirname(resourceUri.toFilePath()));

  // Default static handler for all non-package requests.
  Handler buildDirHandler;
  if (!debugMode) {
    buildDirHandler = createStaticHandler(
      path.join(packageDir, 'build'),
      defaultDocument: 'index.html',
    );
  }

  Handler debugProxyHandler;
  if (debugMode) {
    // Start up a flutter run -d web-server instance.

    const webPort = 9101;

    // ignore: unawaited_futures
    Process.start(
      'flutter',
      ['run', '-d', 'web-server', '--web-port=$webPort'],
      workingDirectory: path.join('..', 'devtools_app'),
    ).then((Process process) {
      // Write all flutter run process output to the server's output.
      process
        ..stdout.transform(utf8.decoder).listen(stdout.write)
        ..stderr.transform(utf8.decoder).listen(stderr.write);

      // Proxy all stdin to the flutter run process's input.
      //stdin.pipe(process.stdin);
      stdin
        ..lineMode = false
        ..listen((event) => process.stdin.add(event));

      // Exit when the flutter run process exits.
      process.exitCode.then(exit);
    });

    debugProxyHandler = proxyHandler(Uri.parse('http://localhost:$webPort/'));
  }

  // The packages folder is renamed in the pub package so this handler serves
  // out of the `pack` folder.
  Handler packHandler;
  if (!debugMode) {
    packHandler = createStaticHandler(
      path.join(packageDir, 'build', 'pack'),
      defaultDocument: 'index.html',
    );
  }

  final sseHandler = SseHandler(Uri.parse('/api/sse'))
    ..connections.rest.listen(clients.acceptClient);

  // Make a handler that delegates based on path.
  final handler = (shelf.Request request) {
    if (!debugMode) {
      if (request.url.path.startsWith('packages/')) {
        // request.change here will strip the `packages` prefix from the path
        // so it's relative to packHandler's root.
        return packHandler(request.change(path: 'packages'));
      }
    }

    if (request.url.path.startsWith('api/sse')) {
      return sseHandler.handler(request);
    }

    if (request.url.path == 'api/ping') {
      return shelf.Response(HttpStatus.ok);
    }

    // The API handler takes all other calls to api/.
    if (ServerApi.canHandle(request)) {
      return ServerApi.handle(request);
    }

    if (debugMode) {
      return debugProxyHandler(request);
    } else {
      return buildDirHandler(request);
    }
  };

  return handler;
}

/// The DevTools server API.
///
/// This defines endpoints that serve all requests that come in over api/.
class ServerApi {
  static const errorNoActiveSurvey = 'ERROR: setActiveSurvey not called.';

  /// Determines whether or not [request] is an API call.
  static bool canHandle(shelf.Request request) {
    return request.url.path.startsWith(apiPrefix);
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
      // ----- Flutter Tool GA store. -----
      case apiGetFlutterGAEnabled:
        // Is Analytics collection enabled?
        return api.getCompleted(
          request,
          json.encode(FlutterUsage.doesStoreExist ? _usage.enabled : null),
        );
      case apiGetFlutterGAClientId:
        // Flutter Tool GA clientId - ONLY get Flutter's clientId if enabled is
        // true.
        return (FlutterUsage.doesStoreExist)
            ? api.getCompleted(
                request,
                json.encode(_usage.enabled ? _usage.clientId : null),
              )
            : api.getCompleted(
                request,
                json.encode(null),
              );

      // ----- DevTools GA store. -----

      case apiResetDevTools:
        _devToolsUsage.reset();
        return api.getCompleted(request, json.encode(true));
      case apiGetDevToolsFirstRun:
        // Has DevTools been run first time? To bring up welcome screen.
        return api.getCompleted(
          request,
          json.encode(_devToolsUsage.isFirstRun),
        );
      case apiGetDevToolsEnabled:
        // Is DevTools Analytics collection enabled?
        return api.getCompleted(request, json.encode(_devToolsUsage.enabled));
      case apiSetDevToolsEnabled:
        // Enable or disable DevTools analytics collection.
        final queryParams = request.requestedUri.queryParameters;
        if (queryParams.containsKey(devToolsEnabledPropertyName)) {
          _devToolsUsage.enabled =
              json.decode(queryParams[devToolsEnabledPropertyName]);
        }
        return api.setCompleted(request, json.encode(_devToolsUsage.enabled));

      // ----- DevTools survey store. -----

      case apiSetActiveSurvey:
        // Assume failure.
        bool result = false;

        // Set the active survey used to store subsequent apiGetSurveyActionTaken,
        // apiSetSurveyActionTaken, apiGetSurveyShownCount, and
        // apiIncrementSurveyShownCount calls.
        final queryParams = request.requestedUri.queryParameters;
        if (queryParams.keys.length == 1 &&
            queryParams.containsKey(activeSurveyName)) {
          final String theSurveyName = queryParams[activeSurveyName];

          // Set the current activeSurvey.
          _devToolsUsage.activeSurvey = theSurveyName;
          result = true;
        }

        return api.getCompleted(request, json.encode(result));
      case apiGetSurveyActionTaken:
        // Request setActiveSurvey has not been requested.
        if (_devToolsUsage.activeSurvey == null) {
          return api.badRequest('$errorNoActiveSurvey '
              '- $apiGetSurveyActionTaken');
        }
        // SurveyActionTaken has the survey been acted upon (taken or dismissed)
        return api.getCompleted(
          request,
          json.encode(_devToolsUsage.surveyActionTaken),
        );
      // TODO(terry): remove the query param logic for this request.
      // setSurveyActionTaken should only be called with the value of true, so
      // we can remove the extra complexity.
      case apiSetSurveyActionTaken:
        // Request setActiveSurvey has not been requested.
        if (_devToolsUsage.activeSurvey == null) {
          return api.badRequest('$errorNoActiveSurvey '
              '- $apiSetSurveyActionTaken');
        }
        // Set the SurveyActionTaken.
        // Has the survey been taken or dismissed..
        final queryParams = request.requestedUri.queryParameters;
        if (queryParams.containsKey(surveyActionTakenPropertyName)) {
          _devToolsUsage.surveyActionTaken =
              json.decode(queryParams[surveyActionTakenPropertyName]);
        }
        return api.setCompleted(
          request,
          json.encode(_devToolsUsage.surveyActionTaken),
        );
      case apiGetSurveyShownCount:
        // Request setActiveSurvey has not been requested.
        if (_devToolsUsage.activeSurvey == null) {
          return api.badRequest('$errorNoActiveSurvey '
              '- $apiGetSurveyShownCount');
        }
        // SurveyShownCount how many times have we asked to take survey.
        return api.getCompleted(
          request,
          json.encode(_devToolsUsage.surveyShownCount),
        );
      case apiIncrementSurveyShownCount:
        // Request setActiveSurvey has not been requested.
        if (_devToolsUsage.activeSurvey == null) {
          return api.badRequest('$errorNoActiveSurvey '
              '- $apiIncrementSurveyShownCount');
        }
        // Increment the SurveyShownCount, we've asked about the survey.
        _devToolsUsage.incrementSurveyShownCount();
        return api.getCompleted(
          request,
          json.encode(_devToolsUsage.surveyShownCount),
        );
      default:
        return api.notImplemented(request);
    }
  }

  // Accessing Flutter usage file e.g., ~/.flutter.
  // NOTE: Only access the file if it exists otherwise Flutter Tool hasn't yet
  //       been run.
  static final FlutterUsage _usage =
      FlutterUsage.doesStoreExist ? FlutterUsage() : null;

  // Accessing DevTools usage file e.g., ~/.devtools
  static final DevToolsUsage _devToolsUsage = DevToolsUsage();

  static DevToolsUsage get devToolsPreferences => _devToolsUsage;

  /// Logs a page view in the DevTools server.
  ///
  /// In the open-source version of DevTools, Google Analytics handles this
  /// without any need to involve the server.
  FutureOr<shelf.Response> logScreenView(shelf.Request request) =>
      notImplemented(request);

  /// Return the value of the property.
  FutureOr<shelf.Response> getCompleted(shelf.Request request, String value) =>
      shelf.Response.ok('$value');

  /// Return the value of the property after the property value has been set.
  FutureOr<shelf.Response> setCompleted(shelf.Request request, String value) =>
      shelf.Response.ok('$value');

  /// A [shelf.Response] for API calls that encountered a request problem e.g.,
  /// setActiveSurvey not called.
  ///
  /// This is a 400 Bad Request response.
  FutureOr<shelf.Response> badRequest([String logError]) {
    if (logError != null) print(logError);
    return shelf.Response(HttpStatus.badRequest);
  }

  /// A [shelf.Response] for API calls that have not been implemented in this
  /// server.
  ///
  /// This is a no-op 204 No Content response because returning 404 Not Found
  /// creates unnecessary noise in the console.
  FutureOr<shelf.Response> notImplemented(shelf.Request request) =>
      shelf.Response(HttpStatus.noContent);
}
