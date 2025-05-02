// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dtd/dtd.dart';
import 'package:meta/meta.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:vm_service/vm_service.dart';

import '../common.dart';
import '../deeplink/deeplink_manager.dart';
import '../devtools_api.dart';
import '../extensions/extension_enablement.dart';
import '../extensions/extension_manager.dart';
import '../service/service.dart';
import '../service_utils.dart';
import '../utils/file_utils.dart';
import 'devtools_store.dart';
import 'file_system.dart';
import 'flutter_store.dart';

// TODO(kenz): consider using Dart augmentation libraries instead of part files
// if there is a clear benefit.
part 'handlers/_app_size.dart';
part 'handlers/_deeplink.dart';
part 'handlers/_devtools_extensions.dart';
part 'handlers/_dtd.dart';
part 'handlers/_vm_service.dart';
part 'handlers/_preferences.dart';
part 'handlers/_release_notes.dart';
part 'handlers/_storage.dart';
part 'handlers/_survey.dart';

/// The DevTools server API.
///
/// This defines endpoints that serve all requests that come in over api/.
class ServerApi {
  static const logsKey = 'logs';
  static const errorKey = 'error';

  /// Determines whether or not [request] is an API call.
  static bool canHandle(shelf.Request request) {
    return request.url.path.startsWith(apiPrefix);
  }

  /// Handles all requests.
  ///
  /// To override an API call, pass in a subclass of [ServerApi].
  static FutureOr<shelf.Response> handle(
    shelf.Request request, {
    required ExtensionsManager extensionsManager,
    required DeeplinkManager deeplinkManager,
    ServerApi? api,
    DtdInfo? dtd,
  }) {
    api ??= ServerApi();
    final queryParams = request.requestedUri.queryParameters;
    switch (request.url.path) {
      case apiNotifyForVmServiceConnection:
        return VmServiceHandler.handleNotifyForVmServiceConnection(
          api,
          queryParams,
          dtd,
        );

      // TODO(kenz): remove legacy analytics once the unified analytics rollout
      // is complete and verified for robustness (est. Fall 2025).

      // ----- Flutter Tool GA store. -----
      case apiGetFlutterGAEnabled:
        // Is Analytics collection enabled?
        return _encodeResponse(
          LocalFileSystem.flutterStoreExists()
              ? _flutterStore.gaEnabled
              : false,
          api: api,
        );
      case apiGetFlutterGAClientId:
        // Flutter Tool GA clientId - ONLY get Flutter's clientId if enabled is
        // true.
        return _encodeResponse(
          LocalFileSystem.flutterStoreExists()
              ? _flutterStore.flutterClientId
              : '',
          api: api,
        );

      // ----- DevTools GA store. -----

      case apiResetDevTools:
        _devToolsStore.reset();
        return _encodeResponse(true, api: api);
      case apiGetDevToolsFirstRun:
        // Has DevTools been run first time? To bring up analytics dialog.
        final isFirstRun = _devToolsStore.isFirstRun;
        return _encodeResponse(isFirstRun, api: api);
      case apiGetDevToolsEnabled:
        // Is DevTools Analytics collection enabled?
        final isEnabled = _devToolsStore.analyticsEnabled;
        return _encodeResponse(isEnabled, api: api);
      case apiSetDevToolsEnabled:
        // Enable or disable DevTools analytics collection.
        if (queryParams.containsKey(devToolsEnabledPropertyName)) {
          final analyticsEnabled =
              json.decode(queryParams[devToolsEnabledPropertyName]!);

          _devToolsStore.analyticsEnabled = analyticsEnabled;
        }
        return _encodeResponse(_devToolsStore.analyticsEnabled, api: api);

      // ----- Preferences api. -----
      case PreferencesApi.getPreferenceValue:
        return _PreferencesApiHandler.getPreferenceValue(
          api,
          queryParams,
          _devToolsStore,
        );

      case PreferencesApi.setPreferenceValue:
        return _PreferencesApiHandler.setPreferenceValue(
          api,
          queryParams,
          _devToolsStore,
        );

      // ----- DevTools survey api. -----

      case SurveyApi.setActiveSurvey:
        return _SurveyHandler.setActiveSurvey(api, queryParams, _devToolsStore);

      case SurveyApi.getSurveyActionTaken:
        return _SurveyHandler.getSurveyActionTaken(api, _devToolsStore);

      case SurveyApi.setSurveyActionTaken:
        return _SurveyHandler.setSurveyActionTaken(api, _devToolsStore);

      case SurveyApi.getSurveyShownCount:
        return _SurveyHandler.getSurveyShownCount(api, _devToolsStore);

      case SurveyApi.incrementSurveyShownCount:
        return _SurveyHandler.incrementSurveyShownCount(api, _devToolsStore);

      // ----- Release notes api. -----

      case ReleaseNotesApi.getLastReleaseNotesVersion:
        return _ReleaseNotesHandler.getLastReleaseNotesVersion(
          api,
          _devToolsStore,
        );

      case ReleaseNotesApi.setLastReleaseNotesVersion:
        return _ReleaseNotesHandler.setLastReleaseNotesVersion(
          api,
          queryParams,
          _devToolsStore,
        );

      // ----- App size api. -----

      case AppSizeApi.getBaseAppSizeFile:
        return _AppSizeHandler.getBaseAppSizeFile(api, queryParams);

      case AppSizeApi.getTestAppSizeFile:
        return _AppSizeHandler.getTestAppSizeFile(api, queryParams);

      // ----- Extensions api. -----

      case ExtensionsApi.apiServeAvailableExtensions:
        return _ExtensionsApiHandler.handleServeAvailableExtensions(
          api,
          queryParams,
          extensionsManager,
          dtd,
        );

      case ExtensionsApi.apiExtensionEnabledState:
        return _ExtensionsApiHandler.handleExtensionEnabledState(
          api,
          queryParams,
        );

      // ----- deeplink api. -----

      case DeeplinkApi.androidBuildVariants:
        return _DeeplinkApiHandler.handleAndroidBuildVariants(
          api,
          queryParams,
          deeplinkManager,
        );

      case DeeplinkApi.androidAppLinkSettings:
        return _DeeplinkApiHandler.handleAndroidAppLinkSettings(
          api,
          queryParams,
          deeplinkManager,
        );

      case DeeplinkApi.iosBuildOptions:
        return _DeeplinkApiHandler.handleIosBuildOptions(
          api,
          queryParams,
          deeplinkManager,
        );

      case DeeplinkApi.iosUniversalLinkSettings:
        return _DeeplinkApiHandler.handleIosUniversalLinkSettings(
          api,
          queryParams,
          deeplinkManager,
        );

      // ----- DTD api. -----

      case DtdApi.apiGetDtdUri:
        return _DtdApiHandler.handleGetDtdUri(api, dtd);

      // ----- Unimplemented. -----

      default:
        return api.notImplemented();
    }
  }

  static shelf.Response _encodeResponse(
    Object? object, {
    required ServerApi api,
  }) {
    return api.success(json.encode(object));
  }

  static Map<String, Object?> _wrapWithLogs(
    Map<String, Object?> result,
    List<String> logs,
  ) {
    result[logsKey] = logs;
    return result;
  }

  static shelf.Response? _checkRequiredParameters(
    List<String> expectedParams, {
    required Map<String, String> queryParams,
    required ServerApi api,
    required String requestName,
  }) {
    final missing = expectedParams.where(
      (param) => !queryParams.containsKey(param),
    );
    return missing.isNotEmpty
        ? api.badRequest(
            '[$requestName] missing required query parameters: '
            '${missing.toList()}',
          )
        : null;
  }

  /// Accessing DevTools store file e.g., ~/.flutter-devtools/.devtools
  static final _devToolsStore = DevToolsUsage();

  /// Accessing Flutter store file e.g., ~/.flutter
  static final _flutterStore = FlutterStore();

  static DevToolsUsage get devToolsPreferences => _devToolsStore;

  /// Provides read and write access to DevTools options files
  /// (e.g. path/to/app/root/devtools_options.yaml).
  static final _devToolsOptions = DevToolsOptions();

  /// Logs a page view in the DevTools server.
  ///
  /// In the open-source version of DevTools, Google Analytics handles this
  /// without any need to involve the server.
  shelf.Response logScreenView() => notImplemented();

  /// A [shelf.Response] for API calls that succeeded.
  ///
  /// The response optionally contains a single String [value].
  shelf.Response success([String? value]) => shelf.Response.ok(value);

  /// A [shelf.Response] for API calls that are forbidden for the current state
  /// of the server.
  shelf.Response forbidden([String? reason]) =>
      shelf.Response.forbidden(reason);

  /// A [shelf.Response] for API calls that encountered a request problem e.g.,
  /// setActiveSurvey not called.
  ///
  /// This is a 400 Bad Request response.
  shelf.Response badRequest([String? error]) {
    if (error != null) print(error);
    return shelf.Response(HttpStatus.badRequest, body: error);
  }

  /// A [shelf.Response] for API calls that encountered a server error e.g.,
  /// setActiveSurvey not called.
  ///
  /// This is a 500 Internal Server Error response.
  shelf.Response serverError([String? error, List<String>? logs]) {
    if (error != null) print(error);
    return shelf.Response(
      HttpStatus.internalServerError,
      body: error != null || logs != null
          ? jsonEncode(<String, Object?>{
              if (error != null) errorKey: error,
              if (logs != null) logsKey: logs,
            })
          : null,
    );
  }

  /// A [shelf.Response] for API calls that have not been implemented in this
  /// server.
  ///
  /// This is a no-op 204 No Content response because returning 404 Not Found
  /// creates unnecessary noise in the console.
  shelf.Response notImplemented() => shelf.Response(HttpStatus.noContent);
}
