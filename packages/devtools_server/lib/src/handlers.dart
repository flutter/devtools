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

/// Access the file '~/.flutter'.
class FlutterUsage {
  /// Create a new Usage instance; [versionOverride] and [configDirOverride] are
  /// used for testing.
  FlutterUsage({
    String settingsName = 'flutter',
    String versionOverride,
    String configDirOverride,
  }) {
    _analytics = AnalyticsIO('', settingsName, '', documentDirectory: null);
  }

  Analytics _analytics;

  /// Does the .flutter store exist?
  static bool get doesStoreExist {
    final flutterStore = File('${DevToolsUsage.userHomeDir()}/.flutter');
    return flutterStore.existsSync();
  }

  bool get isFirstRun => _analytics.firstRun;

  bool get enabled => _analytics.enabled;

  set enabled(bool value) => _analytics.enabled = value;

  String get clientId => _analytics.clientId;
}

// Access the DevTools on disk store (~/.devtools).
class DevToolsUsage {
  /// Create a new Usage instance; [versionOverride] and [configDirOverride] are
  /// used for testing.
  DevToolsUsage({
    String settingsName = 'devtools',
    String versionOverride,
    String configDirOverride,
  }) {
    properties = IOPersistentProperties(
      settingsName,
      documentDirPath: userHomeDir(),
    );
  }

  /// The activeSurvey is the property name of a top-level property
  /// existing or created in the file ~/.devtools
  /// If the property doesn't exist it is created with default survey values:
  ///
  ///   properties[activeSurvey]['surveyActionTaken'] = false;
  ///   properties[activeSurvey]['surveyShownCount'] = 0;
  ///
  /// It is a requirement that the API apiSetActiveSurvey must be called before
  /// calling any survey method on DevToolsUsage (addSurvey, rewriteActiveSurvey,
  /// surveyShownCount, incrementSurveyShownCount, or surveyActionTaken).
  String _activeSurvey;

  static String userHomeDir() {
    final String envKey =
        Platform.operatingSystem == 'windows' ? 'APPDATA' : 'HOME';
    final String value = Platform.environment[envKey];
    return value == null ? '.' : value;
  }

  IOPersistentProperties properties;

  static const String _surveyActionTaken = 'surveyActionTaken';
  static const String _surveyShownCount = 'surveyShownCount';

  void reset() {
    properties.remove('firstRun');
    properties['enabled'] = false;
  }

  bool get isFirstRun {
    properties['firstRun'] = properties['firstRun'] == null;
    return properties['firstRun'];
  }

  bool get enabled {
    if (properties['enabled'] == null) {
      properties['enabled'] = false;
    }

    return properties['enabled'];
  }

  set enabled(bool value) {
    properties['enabled'] = value;
    return properties['enabled'];
  }

  bool surveyNameExists(String surveyName) => properties[surveyName] != null;

  void _addSurvey(String surveyName) {
    assert(activeSurvey != null);
    assert(activeSurvey == surveyName);
    rewriteActiveSurvey(false, 0);
  }

  String get activeSurvey => _activeSurvey;

  set activeSurvey(String surveyName) {
    assert(surveyName != null);
    _activeSurvey = surveyName;

    if (!surveyNameExists(activeSurvey)) {
      // Create the survey if property is non-existent in ~/.devtools
      _addSurvey(activeSurvey);
    }
  }

  /// Need to rewrite the entire survey structure for property to be persisted.
  void rewriteActiveSurvey(bool actionTaken, int shownCount) {
    assert(activeSurvey != null);
    properties[activeSurvey] = {
      _surveyActionTaken: actionTaken,
      _surveyShownCount: shownCount,
    };
  }

  int get surveyShownCount {
    assert(activeSurvey != null);
    final prop = properties[activeSurvey];
    if (prop[_surveyShownCount] == null) {
      rewriteActiveSurvey(prop[_surveyActionTaken], 0);
    }
    return properties[activeSurvey][_surveyShownCount];
  }

  void incrementSurveyShownCount() {
    assert(activeSurvey != null);
    surveyShownCount; // Ensure surveyShownCount has been initialized.
    final prop = properties[activeSurvey];
    rewriteActiveSurvey(prop[_surveyActionTaken], prop[_surveyShownCount] + 1);
  }

  bool get surveyActionTaken {
    assert(activeSurvey != null);
    return properties[activeSurvey][_surveyActionTaken] == true;
  }

  set surveyActionTaken(bool value) {
    assert(activeSurvey != null);
    final prop = properties[activeSurvey];
    rewriteActiveSurvey(value, prop[_surveyShownCount]);
  }
}

abstract class PersistentProperties {
  PersistentProperties(this.name);

  final String name;

  dynamic operator [](String key);

  void operator []=(String key, dynamic value);

  /// Re-read settings from the backing store.
  ///
  /// May be a no-op on some platforms.
  void syncSettings();
}

const JsonEncoder _jsonEncoder = JsonEncoder.withIndent('  ');

class IOPersistentProperties extends PersistentProperties {
  IOPersistentProperties(
    String name, {
    String documentDirPath,
  }) : super(name) {
    final String fileName = '.${name.replaceAll(' ', '_')}';
    documentDirPath ??= DevToolsUsage.userHomeDir();
    _file = File(path.join(documentDirPath, fileName));
    if (!_file.existsSync()) {
      _file.createSync();
    }
    syncSettings();
  }

  IOPersistentProperties.fromFile(File file) : super(path.basename(file.path)) {
    _file = file;
    if (!_file.existsSync()) {
      _file.createSync();
    }
    syncSettings();
  }

  File _file;

  Map _map;

  @override
  dynamic operator [](String key) => _map[key];

  @override
  void operator []=(String key, dynamic value) {
    if (value == null && !_map.containsKey(key)) return;
    if (_map[key] == value) return;

    if (value == null) {
      _map.remove(key);
    } else {
      _map[key] = value;
    }

    try {
      _file.writeAsStringSync(_jsonEncoder.convert(_map) + '\n');
    } catch (_) {}
  }

  @override
  void syncSettings() {
    try {
      String contents = _file.readAsStringSync();
      if (contents.isEmpty) contents = '{}';
      _map = jsonDecode(contents);
    } catch (_) {
      _map = {};
    }
  }

  void remove(String propertyName) {
    _map.remove(propertyName);
  }
}
