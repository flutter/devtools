// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:devtools_shared/devtools_deeplink.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';

import '../../development_helpers.dart';
import '../../primitives/utils.dart';

final _log = Logger('_server_web');

// The DevTools server is only available in release mode right now.
// TODO(kenz): design a way to run the DevTools server and DevTools app together
// in debug mode.
bool get isDevToolsServerAvailable => kReleaseMode;

/// Helper to catch any server request which could fail.
///
/// Returns HttpRequest or null (if server failure).
Future<Response?> request(String url) async {
  Response? response;

  try {
    response = await post(Uri.parse(url));
  } catch (_) {}

  return response;
}

/// Request DevTools property value 'firstRun' (GA dialog) stored in the file
/// '~/flutter-devtools/.devtools'.
Future<bool> isFirstRun() async {
  bool firstRun = false;

  if (isDevToolsServerAvailable) {
    final resp = await request(apiGetDevToolsFirstRun);
    if (resp?.statusCode == 200) {
      firstRun = json.decode(resp!.body);
    } else {
      logWarning(resp, apiGetDevToolsFirstRun);
    }
  }

  return firstRun;
}

/// Request DevTools property value 'enabled' (GA enabled) stored in the file
/// '~/.flutter-devtools/.devtools'.
Future<bool> isAnalyticsEnabled() async {
  bool enabled = false;
  if (isDevToolsServerAvailable) {
    final resp = await request(apiGetDevToolsEnabled);
    if (resp?.statusOk ?? false) {
      enabled = json.decode(resp!.body);
    } else {
      logWarning(resp, apiGetDevToolsEnabled);
    }
  }
  return enabled;
}

/// Set the DevTools property 'enabled' (GA enabled) stored in the file
/// '~/.flutter-devtools/.devtools'.
///
/// Returns whether the set call was successful.
Future<bool> setAnalyticsEnabled([bool value = true]) async {
  if (isDevToolsServerAvailable) {
    final resp = await request(
      '$apiSetDevToolsEnabled'
      '?$devToolsEnabledPropertyName=$value',
    );
    if (resp?.statusOk ?? false) {
      assert(json.decode(resp!.body) == value);
      return true;
    } else {
      logWarning(resp, apiSetDevToolsEnabled, resp?.body);
    }
  }
  return false;
}

// TODO(terry): Move to an API scheme similar to the VM service extension where
// '/api/devToolsEnabled' returns the value (identical VM service) and
// '/api/devToolsEnabled?value=true' sets the value.

/// Request Flutter tool stored property value enabled (GA enabled) stored in
/// the file '~\.flutter'.
///
/// Return bool.
/// Return value of false implies either GA is disabled or the Flutter Tool has
/// never been run (null returned from the server).
Future<bool> _isFlutterGAEnabled() async {
  bool enabled = false;

  if (isDevToolsServerAvailable) {
    final resp = await request(apiGetFlutterGAEnabled);
    if (resp?.statusOk ?? false) {
      // A return value of 'null' implies Flutter tool has never been run so
      // return false for Flutter GA enabled.
      final responseValue = json.decode(resp!.body);
      enabled = responseValue ?? false;
    } else {
      logWarning(resp, apiGetFlutterGAEnabled);
    }
  }

  return enabled;
}

/// Request Flutter tool stored property value clientID (GA enabled) stored in
/// the file '~\.flutter'.
///
/// Return as a String, empty string implies Flutter Tool has never been run.
Future<String> flutterGAClientID() async {
  // Default empty string, Flutter tool never run.
  String clientId = '';

  if (isDevToolsServerAvailable) {
    // Test if Flutter is enabled (or if Flutter Tool ever ran) if not enabled
    // is false, we don't want to be the first to create a ~/.flutter file.
    if (await _isFlutterGAEnabled()) {
      final resp = await request(apiGetFlutterGAClientId);
      if (resp?.statusOk ?? false) {
        clientId = json.decode(resp!.body);
        if (clientId.isEmpty) {
          // Requested value of 'null' (Flutter tool never ran). Server request
          // apiGetFlutterGAClientId should not happen because the
          // isFlutterGAEnabled test should have been false.
          _log.warning('$apiGetFlutterGAClientId is empty');
        }
      } else {
        logWarning(resp, apiGetFlutterGAClientId);
      }
    }
  }

  return clientId;
}

/// Set DevTools parameter value for the active survey (e.g. 'Q1-2020').
///
/// The value is stored in the file '~/.flutter-devtools/.devtools'.
///
/// This method must be called before calling other survey related methods
/// ([isSurveyActionTaken], [setSurveyActionTaken], [surveyShownCount],
/// [incrementSurveyShownCount]). If the active survey is not set, warnings are
/// logged.
Future<bool> setActiveSurvey(String value) async {
  if (isDevToolsServerAvailable) {
    final resp = await request(
      '$apiSetActiveSurvey'
      '?$activeSurveyName=$value',
    );
    if ((resp?.statusOk ?? false) && json.decode(resp!.body)) {
      return true;
    } else {
      logWarning(resp, apiSetActiveSurvey);
    }
  }
  return false;
}

/// Request DevTools property value 'surveyActionTaken' for the active survey.
///
/// The value is stored in the file '~/.flutter-devtools/.devtools'.
///
/// Requires [setActiveSurvey] to have been called prior to calling this method.
Future<bool> surveyActionTaken() async {
  bool surveyActionTaken = false;

  if (isDevToolsServerAvailable) {
    final resp = await request(apiGetSurveyActionTaken);
    if (resp?.statusOk ?? false) {
      surveyActionTaken = json.decode(resp!.body);
    } else {
      logWarning(resp, apiGetSurveyActionTaken);
    }
  }

  return surveyActionTaken;
}

/// Set DevTools property value 'surveyActionTaken' for the active survey.
///
/// The value is stored in the file '~/.flutter-devtools/.devtools'.
///
/// Requires [setActiveSurvey] to have been called prior to calling this method.
Future<void> setSurveyActionTaken() async {
  if (isDevToolsServerAvailable) {
    final resp = await request(
      '$apiSetSurveyActionTaken'
      '?$surveyActionTakenPropertyName=true',
    );
    if (resp == null || !resp.statusOk || !json.decode(resp.body)) {
      logWarning(resp, apiSetSurveyActionTaken, resp?.body);
    }
  }
}

/// Request DevTools property value 'surveyShownCount' for the active survey.
///
/// The value is stored in the file '~/.flutter-devtools/.devtools'.
///
/// Requires [setActiveSurvey] to have been called prior to calling this method.
Future<int> surveyShownCount() async {
  int surveyShownCount = 0;

  if (isDevToolsServerAvailable) {
    final resp = await request(apiGetSurveyShownCount);
    if (resp?.statusOk ?? false) {
      surveyShownCount = json.decode(resp!.body);
    } else {
      logWarning(resp, apiGetSurveyShownCount);
    }
  }

  return surveyShownCount;
}

/// Increment DevTools property value 'surveyShownCount' for the active survey.
///
/// The value is stored in the file '~/.flutter-devtools/.devtools'.
///
/// Requires [setActiveSurvey] to have been called prior to calling this method.
Future<int> incrementSurveyShownCount() async {
  // Any failure will still return 0.
  int surveyShownCount = 0;

  if (isDevToolsServerAvailable) {
    final resp = await request(apiIncrementSurveyShownCount);
    if (resp?.statusOk ?? false) {
      surveyShownCount = json.decode(resp!.body);
    } else {
      logWarning(resp, apiIncrementSurveyShownCount);
    }
  }
  return surveyShownCount;
}

/// Requests the DevTools version for which we last showed release notes.
///
/// This value is stored in the file '~/.flutter-devtools/.devtools'.
Future<String> getLastShownReleaseNotesVersion() async {
  String version = '';
  if (isDevToolsServerAvailable) {
    final resp = await request(apiGetLastReleaseNotesVersion);
    if (resp?.statusOk ?? false) {
      version = json.decode(resp!.body);
    } else {
      logWarning(resp, apiGetLastReleaseNotesVersion);
    }
  }
  return version;
}

/// Sets the DevTools version for which we last showed release notes.
///
/// This value is stored in the file '~/.flutter-devtools/.devtools'.
Future<void> setLastShownReleaseNotesVersion(String version) async {
  if (isDevToolsServerAvailable) {
    final resp = await request(
      '$apiSetLastReleaseNotesVersion'
      '?$lastReleaseNotesVersionPropertyName=$version',
    );
    if (resp == null || !resp.statusOk || !json.decode(resp.body)) {
      logWarning(resp, apiSetLastReleaseNotesVersion, resp?.body);
    }
  }
}

// currently unused
/// Requests all .devtools properties to be reset to their default values in the
/// file '~/.flutter-devtools/.devtools'.
Future<void> resetDevToolsFile() async {
  if (isDevToolsServerAvailable) {
    final resp = await request(apiResetDevTools);
    if (resp?.statusOk ?? false) {
      assert(json.decode(resp!.body));
    } else {
      logWarning(resp, apiResetDevTools);
    }
  }
}

Future<DevToolsJsonFile?> requestBaseAppSizeFile(String path) {
  return requestFile(
    api: apiGetBaseAppSizeFile,
    fileKey: baseAppSizeFilePropertyName,
    filePath: path,
  );
}

Future<DevToolsJsonFile?> requestTestAppSizeFile(String path) {
  return requestFile(
    api: apiGetTestAppSizeFile,
    fileKey: testAppSizeFilePropertyName,
    filePath: path,
  );
}

Future<DevToolsJsonFile?> requestFile({
  required String api,
  required String fileKey,
  required String filePath,
}) async {
  if (isDevToolsServerAvailable) {
    final url = Uri(path: api, queryParameters: {fileKey: filePath});
    final resp = await request(url.toString());
    if (resp?.statusOk ?? false) {
      return _devToolsJsonFileFromResponse(resp!, filePath);
    } else {
      logWarning(resp, api);
    }
  }
  return null;
}

DevToolsJsonFile _devToolsJsonFileFromResponse(
  Response resp,
  String filePath,
) {
  final data = json.decode(resp.body);
  final lastModified = data['lastModifiedTime'];
  final lastModifiedTime =
      lastModified != null ? DateTime.parse(lastModified) : DateTime.now();
  return DevToolsJsonFile(
    name: filePath,
    lastModifiedTime: lastModifiedTime,
    data: data,
  );
}

/// Makes a request to the server to refresh the list of available extensions,
/// serve their assets on the server, and return the list of available
/// extensions here.
Future<List<DevToolsExtensionConfig>> refreshAvailableExtensions(
  String rootPath,
) async {
  if (isDevToolsServerAvailable) {
    final uri = Uri(
      path: ExtensionsApi.apiServeAvailableExtensions,
      queryParameters: {ExtensionsApi.extensionRootPathPropertyName: rootPath},
    );
    final resp = await request(uri.toString());
    if (resp?.statusOk ?? false) {
      final parsedResult = json.decode(resp!.body);
      final extensionsAsJson =
          (parsedResult[ExtensionsApi.extensionsResultPropertyName]!
                  as List<Object?>)
              .whereNotNull()
              .cast<Map<String, Object?>>();

      final warningMessage =
          parsedResult[ExtensionsApi.extensionsResultWarningPropertyName];
      if (warningMessage != null) {
        _log.warning(warningMessage);
      }

      return extensionsAsJson
          .map((p) => DevToolsExtensionConfig.parse(p))
          .toList();
    } else {
      logWarning(resp, ExtensionsApi.apiServeAvailableExtensions);
      return [];
    }
  } else if (debugDevToolsExtensions) {
    return debugHandleRefreshAvailableExtensions(rootPath);
  }
  return [];
}

/// Makes a request to the server to look up the enabled state for a
/// DevTools extension, and optionally to set the enabled state (when [enable]
/// is non-null).
///
/// If [enable] is specified, the server will first set the enabled state
/// to the value set forth by [enable] and then return the value that is saved
/// to disk.
Future<ExtensionEnabledState> extensionEnabledState({
  required String rootPath,
  required String extensionName,
  bool? enable,
}) async {
  if (isDevToolsServerAvailable) {
    final uri = Uri(
      path: ExtensionsApi.apiExtensionEnabledState,
      queryParameters: {
        ExtensionsApi.extensionRootPathPropertyName: rootPath,
        ExtensionsApi.extensionNamePropertyName: extensionName,
        if (enable != null)
          ExtensionsApi.enabledStatePropertyName: enable.toString(),
      },
    );
    final resp = await request(uri.toString());
    if (resp?.statusOk ?? false) {
      final parsedResult = json.decode(resp!.body);
      return ExtensionEnabledState.from(parsedResult);
    } else {
      logWarning(resp, ExtensionsApi.apiExtensionEnabledState);
    }
  } else if (debugDevToolsExtensions) {
    return debugHandleExtensionEnabledState(
      rootPath: rootPath,
      extensionName: extensionName,
      enable: enable,
    );
  }
  return ExtensionEnabledState.error;
}

Future<List<String>> requestAndroidBuildVariants(String path) async {
  if (isDevToolsServerAvailable) {
    final uri = Uri(
      path: DeeplinkApi.androidBuildVariants,
      queryParameters: {
        DeeplinkApi.deeplinkRootPathPropertyName: path,
      },
    );
    final resp = await request(uri.toString());
    if (resp?.statusOk ?? false) {
      return json.decode(resp!.body);
    } else {
      logWarning(resp, DeeplinkApi.androidBuildVariants);
    }
  }
  return const <String>[];
}

Future<AppLinkSettings> requestAndroidAppLinkSettings(
  String path, {
  required String buildVariant,
}) async {
  if (isDevToolsServerAvailable) {
    final uri = Uri(
      path: DeeplinkApi.androidAppLinkSettings,
      queryParameters: {
        DeeplinkApi.deeplinkRootPathPropertyName: path,
        DeeplinkApi.androidBuildVariantPropertyName: buildVariant,
      },
    );
    final resp = await request(uri.toString());
    if (resp?.statusOk ?? false) {
      return AppLinkSettings.fromJson(resp!.body);
    } else {
      logWarning(resp, DeeplinkApi.androidAppLinkSettings);
    }
  }
  return AppLinkSettings.empty;
}

Future<XcodeBuildOptions> requestIosBuildOptions(String path) async {
  if (isDevToolsServerAvailable) {
    final uri = Uri(
      path: DeeplinkApi.iosBuildOptions,
      queryParameters: {
        DeeplinkApi.deeplinkRootPathPropertyName: path,
      },
    );
    final resp = await request(uri.toString());
    if (resp?.statusOk ?? false) {
      return XcodeBuildOptions.fromJson(resp!.body);
    } else {
      logWarning(resp, DeeplinkApi.iosBuildOptions);
    }
  }
  return XcodeBuildOptions.empty;
}

Future<UniversalLinkSettings> requestIosUniversalLinkSettings(
  String path, {
  required String configuration,
  required String target,
}) async {
  if (isDevToolsServerAvailable) {
    final uri = Uri(
      path: DeeplinkApi.iosUniversalLinkSettings,
      queryParameters: {
        DeeplinkApi.deeplinkRootPathPropertyName: path,
        DeeplinkApi.xcodeConfigurationPropertyName: configuration,
        DeeplinkApi.xcodeTargetPropertyName: target,
      },
    );
    final resp = await request(uri.toString());
    if (resp?.statusOk ?? false) {
      return UniversalLinkSettings.fromJson(resp!.body);
    } else {
      logWarning(resp, DeeplinkApi.iosUniversalLinkSettings);
    }
  }
  return UniversalLinkSettings.empty;
}

void logWarning(Response? response, String apiType, [String? respText]) {
  _log.warning(
    'HttpRequest $apiType failed status = ${response?.statusCode}'
    '${respText != null ? ', responseText = $respText' : ''}',
  );
}

extension ResponseExtension on Response {
  bool get statusOk => statusCode == 200;
}