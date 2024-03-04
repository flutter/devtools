// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_classes_with_only_static_members, avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:unified_analytics/unified_analytics.dart';

import '../deeplink/deeplink_manager.dart';
import '../devtools_api.dart';
import '../extensions/extension_enablement.dart';
import '../extensions/extension_manager.dart';
import 'file_system.dart';
import 'usage.dart';

// TODO(kenz): consider using Dart augmentation libraries instead of part files
// if there is a clear benefit.
part 'handlers/_deeplink.dart';
part 'handlers/_devtools_extensions.dart';
part 'handlers/_dtd.dart';

/// The DevTools server API.
///
/// This defines endpoints that serve all requests that come in over api/.
class ServerApi {
  static const logsKey = 'logs';
  static const errorKey = 'error';
  static const errorNoActiveSurvey = 'ERROR: setActiveSurvey not called.';

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
    required Analytics analytics,
    ServerApi? api,
    String? dtdUri,
  }) {
    api ??= ServerApi();
    final queryParams = request.requestedUri.queryParameters;
    // TODO(kenz): break this switch statement up so that it uses helper methods
    // for each case. Also use [_checkRequiredParameters] and [_encodeResponse]
    // helpers.
    switch (request.url.path) {
      // ----- Flutter Tool GA store. -----
      case apiGetFlutterGAEnabled:
        // Is Analytics collection enabled?
        return api.getCompleted(
          json.encode(FlutterUsage.doesStoreExist ? _usage!.enabled : ''),
        );
      case apiGetFlutterGAClientId:
        // Flutter Tool GA clientId - ONLY get Flutter's clientId if enabled is
        // true.
        return (FlutterUsage.doesStoreExist)
            ? api.getCompleted(
                json.encode(_usage!.enabled ? _usage!.clientId : ''),
              )
            : api.getCompleted(
                json.encode(''),
              );

      // ----- DevTools GA store. -----

      case apiResetDevTools:
        _devToolsUsage.reset();
        return api.getCompleted(json.encode(true));
      case apiGetDevToolsFirstRun:
        // Has DevTools been run first time? To bring up analytics dialog.
        //
        // Additionally, package:unified_analytics will show a message if it
        // is the first run with the package or the consent message version has
        // been updated
        final isFirstRun =
            _devToolsUsage.isFirstRun || analytics.shouldShowMessage;
        return api.getCompleted(
          json.encode(isFirstRun),
        );
      case apiGetDevToolsEnabled:
        // Is DevTools Analytics collection enabled?
        final isEnabled =
            _devToolsUsage.analyticsEnabled && analytics.telemetryEnabled;
        return api.getCompleted(
          json.encode(isEnabled),
        );
      case apiSetDevToolsEnabled:
        // Enable or disable DevTools analytics collection.
        if (queryParams.containsKey(devToolsEnabledPropertyName)) {
          final analyticsEnabled =
              json.decode(queryParams[devToolsEnabledPropertyName]!);

          _devToolsUsage.analyticsEnabled = analyticsEnabled;
          analytics.setTelemetry(analyticsEnabled);
        }
        return api.getCompleted(
          json.encode(_devToolsUsage.analyticsEnabled),
        );
      case apiGetConsentMessage:
        return api.getCompleted(analytics.getConsentMessage);
      case apiMarkConsentMessageAsShown:
        analytics.clientShowedMessage();
        return api.getCompleted(json.encode(true));

      // ----- DevTools survey store. -----

      case apiSetActiveSurvey:
        // Assume failure.
        bool result = false;

        // Set the active survey used to store subsequent apiGetSurveyActionTaken,
        // apiSetSurveyActionTaken, apiGetSurveyShownCount, and
        // apiIncrementSurveyShownCount calls.
        if (queryParams.keys.length == 1 &&
            queryParams.containsKey(activeSurveyName)) {
          final String theSurveyName = queryParams[activeSurveyName]!;

          // Set the current activeSurvey.
          _devToolsUsage.activeSurvey = theSurveyName;
          result = true;
        }

        return api.getCompleted(json.encode(result));
      case apiGetSurveyActionTaken:
        // Request setActiveSurvey has not been requested.
        if (_devToolsUsage.activeSurvey == null) {
          return api.badRequest(
            '$errorNoActiveSurvey '
            '- $apiGetSurveyActionTaken',
          );
        }
        // SurveyActionTaken has the survey been acted upon (taken or dismissed)
        return api.getCompleted(
          json.encode(_devToolsUsage.surveyActionTaken),
        );
      // TODO(terry): remove the query param logic for this request.
      // setSurveyActionTaken should only be called with the value of true, so
      // we can remove the extra complexity.
      case apiSetSurveyActionTaken:
        // Request setActiveSurvey has not been requested.
        if (_devToolsUsage.activeSurvey == null) {
          return api.badRequest(
            '$errorNoActiveSurvey '
            '- $apiSetSurveyActionTaken',
          );
        }
        // Set the SurveyActionTaken.
        // Has the survey been taken or dismissed..
        if (queryParams.containsKey(surveyActionTakenPropertyName)) {
          _devToolsUsage.surveyActionTaken =
              json.decode(queryParams[surveyActionTakenPropertyName]!);
        }
        return api.getCompleted(
          json.encode(_devToolsUsage.surveyActionTaken),
        );
      case apiGetSurveyShownCount:
        // Request setActiveSurvey has not been requested.
        if (_devToolsUsage.activeSurvey == null) {
          return api.badRequest(
            '$errorNoActiveSurvey '
            '- $apiGetSurveyShownCount',
          );
        }
        // SurveyShownCount how many times have we asked to take survey.
        return api.getCompleted(
          json.encode(_devToolsUsage.surveyShownCount),
        );
      case apiIncrementSurveyShownCount:
        // Request setActiveSurvey has not been requested.
        if (_devToolsUsage.activeSurvey == null) {
          return api.badRequest(
            '$errorNoActiveSurvey '
            '- $apiIncrementSurveyShownCount',
          );
        }
        // Increment the SurveyShownCount, we've asked about the survey.
        _devToolsUsage.incrementSurveyShownCount();
        return api.getCompleted(
          json.encode(_devToolsUsage.surveyShownCount),
        );

      // ----- Release notes api. -----

      case apiGetLastReleaseNotesVersion:
        return api.getCompleted(
          json.encode(_devToolsUsage.lastReleaseNotesVersion),
        );
      case apiSetLastReleaseNotesVersion:
        if (queryParams.containsKey(lastReleaseNotesVersionPropertyName)) {
          _devToolsUsage.lastReleaseNotesVersion =
              queryParams[lastReleaseNotesVersionPropertyName]!;
        }
        return api.getCompleted(
          json.encode(_devToolsUsage.lastReleaseNotesVersion),
        );

      // ----- App size api. -----

      case apiGetBaseAppSizeFile:
        if (queryParams.containsKey(baseAppSizeFilePropertyName)) {
          final filePath = queryParams[baseAppSizeFilePropertyName]!;
          final fileJson = LocalFileSystem.devToolsFileAsJson(filePath);
          if (fileJson == null) {
            return api.badRequest('No JSON file available at $filePath.');
          }
          return api.getCompleted(fileJson);
        }
        return api.badRequest(
          'Request for base app size file does not '
          'contain a query parameter with the expected key: '
          '$baseAppSizeFilePropertyName',
        );
      case apiGetTestAppSizeFile:
        if (queryParams.containsKey(testAppSizeFilePropertyName)) {
          final filePath = queryParams[testAppSizeFilePropertyName]!;
          final fileJson = LocalFileSystem.devToolsFileAsJson(filePath);
          if (fileJson == null) {
            return api.badRequest('No JSON file available at $filePath.');
          }
          return api.getCompleted(fileJson);
        }
        return api.badRequest(
          'Request for test app size file does not '
          'contain a query parameter with the expected key: '
          '$testAppSizeFilePropertyName',
        );

      // ----- Extensions api. -----

      case ExtensionsApi.apiServeAvailableExtensions:
        return _ExtensionsApiHandler.handleServeAvailableExtensions(
          api,
          queryParams,
          extensionsManager,
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
      case DtdApi.apiGetDtdUri:
        return _DtdApiHandler.handleGetDtdUri(api, dtdUri);
      default:
        return api.notImplemented();
    }
  }

  static shelf.Response _encodeResponse(
    Object? object, {
    required ServerApi api,
  }) {
    return api.getCompleted(json.encode(object));
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

  // Accessing Flutter usage file e.g., ~/.flutter.
  // NOTE: Only access the file if it exists otherwise Flutter Tool hasn't yet
  //       been run.
  static final FlutterUsage? _usage =
      FlutterUsage.doesStoreExist ? FlutterUsage() : null;

  // Accessing DevTools usage file e.g., ~/.flutter-devtools/.devtools
  static final _devToolsUsage = DevToolsUsage();

  static DevToolsUsage get devToolsPreferences => _devToolsUsage;

  /// Provides read and write access to DevTools options files
  /// (e.g. path/to/app/root/devtools_options.yaml).
  static final _devToolsOptions = DevToolsOptions();

  /// Logs a page view in the DevTools server.
  ///
  /// In the open-source version of DevTools, Google Analytics handles this
  /// without any need to involve the server.
  shelf.Response logScreenView() => notImplemented();

  /// Return the value of the property.
  shelf.Response getCompleted(String value) => shelf.Response.ok(value);

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
