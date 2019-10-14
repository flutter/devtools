// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

      // ----- Flutter Tool GA store. -----
      case 'api/getFlutterGAEnabled':
        // Is Analytics collection enabled?
        return api.getCompleted(
          request,
          '${Usage.doesStoreExits ? _usage.enabled : 'null'}',
        );
      case 'api/getFlutterGAClientId':
        // Flutter Tool GA clientId - ONLY get Flutter's clientId if enabled is
        // true.
        return (Usage.doesStoreExits)
            ? api.getCompleted(
                request, _usage.enabled ? _usage.clientId : 'null')
            : api.getCompleted(request, 'null');

      // ----- DevTools GA store. -----
      case 'api/resetDevTools':
        _devToolsUsage.reset();
        return api.getCompleted(request, 'true');
      case 'api/getDevToolsFirstRun':
        // Has DevTools been run first time? To bring up welcome screen.
        return api.getCompleted(request, '${_devToolsUsage.isFirstRun}');
      case 'api/getDevToolsEnabled':
        // Is DevTools Analytics collection enabled?
        return api.getCompleted(request, '${_devToolsUsage.enabled}');
      case 'api/setDevToolsEnabled':
        // Enable or disable DevTools analytics collection.
        final queryParams = request.requestedUri.queryParameters;
        _devToolsUsage.enabled = queryParams.containsKey('enabled')
            ? queryParams['enabled'] == 'true'
            : false;
        return api.setCompleted(request, '${_devToolsUsage.enabled}');

      // ----- DevTools survey store. -----
      case 'api/getSurveyActionTaken':
        // SurveyActionTaken has the survey be taken?
        return api.getCompleted(request, '${_devToolsUsage.surveyActionTaken}');
      case 'api/setSurveyActionTaken':
        // Set the SurveyActionTaken.
        // Enable or disable analytics collection.
        final queryParams = request.requestedUri.queryParameters;
        _devToolsUsage.surveyActionTaken =
            queryParams.containsKey('surveyActionTaken')
                ? queryParams['surveyActionTaken'] == 'true'
                : false;
        return api.setCompleted(request, '${_devToolsUsage.surveyActionTaken}');
      case 'api/getSurveyShownCount':
        // SurveyShownCount how many times have we asked to take survey.
        return api.getCompleted(request, '${_devToolsUsage.surveyShownCount}');
      case 'api/incrementSurveyShownCount':
        // Increment the SurveyShownCount, we've asked about the survey.
        _devToolsUsage.incrementSurveyShownCount();
        return api.getCompleted(request, '${_devToolsUsage.surveyShownCount}');
      default:
        return api.notImplemented(request);
    }
  }

  // Accessing Flutter usage file e.g., ~/.flutter.
  // NOTE: Only access the file if it exists otherwise Flutter Tool hasn't yet
  //       been run.
  static final Usage _usage = Usage.doesStoreExits ? Usage() : null;

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

  /// A [shelf.Response] for API calls that have not been implemented in this
  /// server.
  ///
  /// This is a no-op 204 No Content response because returning 404 Not Found
  /// creates unnecessary noise in the console.
  FutureOr<shelf.Response> notImplemented(shelf.Request request) =>
      shelf.Response(204);
}

// Access the ~/.flutter file.
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

  /// Does the .flutter store exist?
  static bool get doesStoreExits {
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
  DevToolsUsage(
      {String settingsName = 'devtools',
      String versionOverride,
      String configDirOverride}) {
    // final FlutterVersion flutterVersion = FlutterVersion.instance;
    // final String version = versionOverride ?? flutterVersion.getVersionString(redactUnknownBranches: true);
    // TODO(terry): UA, first parameter, is '' could be DevTools UA
    // TODO(terry): version, second parameter, is '' could be real Flutter version #.
    // TODO(terry): documentDirectory, third parameter, is null could be :
    //    documentDirectory: configDirOverride != null ? fs.directory(configDirOverride) : null

    properties =
        IOPersistentProperties(settingsName, documentDirPath: userHomeDir());
  }

  static String userHomeDir() {
    final String envKey =
        Platform.operatingSystem == 'windows' ? 'APPDATA' : 'HOME';
    final String value = Platform.environment[envKey];
    return value == null ? '.' : value;
  }

  IOPersistentProperties properties;

  void reset() {
    properties.remove('firstRun');
    properties['enabled'] = false;
    properties['surveyShownCount'] = 0;
    properties['surveyActionTaken'] = false;
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

  int get surveyShownCount {
    if (properties['surveyShownCount'] == null) {
      properties['surveyShownCount'] = 0;
    }

    return properties['surveyShownCount'];
  }

  void incrementSurveyShownCount() {
    surveyShownCount; // Insure surveyShownCount has been initialized.
    properties['surveyShownCount'] += 1;
  }

  bool get surveyActionTaken => properties['surveyActionTaken'] == true;

  set surveyActionTaken(bool value) {
    properties['surveyActionTaken'] = value;
  }
}

abstract class PersistentProperties {
  PersistentProperties(this.name);

  final String name;

  dynamic operator [](String key);
  void operator []=(String key, dynamic value);

  /// Re-read settings from the backing store. This may be a no-op on some
  /// platforms.
  void syncSettings();
}

const JsonEncoder _jsonEncoder = JsonEncoder.withIndent('  ');

class IOPersistentProperties extends PersistentProperties {
  IOPersistentProperties(String name, {String documentDirPath}) : super(name) {
    String fileName = '.${name.replaceAll(' ', '_')}';
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

  remove(String propertyName) {
    _map.remove(propertyName);
  }
}
