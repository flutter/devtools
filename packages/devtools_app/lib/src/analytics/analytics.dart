// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@JS()
library gtags;

// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'package:devtools_shared/devtools_shared.dart' as server;
import 'package:js/js.dart';
import 'package:js/js_util.dart';

import '../../devtools.dart' as devtools show version;
import '../config_specific/logger/logger.dart';
import '../globals.dart';
import '../ui/gtags.dart';
import '../utils.dart';
import '../version.dart';
import 'constants.dart';

// Dimensions1 AppType values:
const String appTypeFlutter = 'flutter';
const String appTypeWeb = 'web';
// Dimensions2 BuildType values:
const String buildTypeDebug = 'debug';
const String buildTypeProfile = 'profile';
// Dimensions3 PlatformType values:
//    android
//    linux
//    ios
//    macos
//    windows
//    fuchsia
//    unknown     VM Service before version 3.24
// Dimension4 devToolsPlatformType values:
const String devToolsPlatformTypeMac = 'MacIntel';
const String devToolsPlatformTypeLinux = 'Linux';
const String devToolsPlatformTypeWindows = 'Windows';
// Start with Android_n.n.n
const String devToolsPlatformTypeAndroid = 'Android_';
// Dimension5 devToolsChrome starts with
const String devToolsChromeName = 'Chrome/'; // starts with and ends with n.n.n
const String devToolsChromeIos = 'Crios/'; // starts with and ends with n.n.n
const String devToolsChromeOS = 'CrOS'; // Chrome OS
// Dimension6 devToolsVersion

// Dimension7 ideLaunched
const String ideLaunchedQuery = 'ide'; // '&ide=' query parameter
const String ideLaunchedCLI = 'CLI'; // Command Line Interface

@JS('gtagsEnabled')
external bool isGtagsEnabled();

/// Is the query parameter &gtags= set to reset?
@JS('gtagsReset')
external bool isGtagsReset();

@JS('initializeGA')
external void initializeGA();

@JS()
@anonymous
class GtagEventDevTools extends GtagEvent {
  external factory GtagEventDevTools({
    String event_category,
    String event_label, // Event e.g., gaScreenViewEvent, gaSelectEvent, etc.
    String send_to, // UA ID of target GA property to receive event data.

    int value,
    bool non_interaction,
    dynamic custom_map,
    String user_app, // dimension1 (flutter or web)
    String user_build, // dimension2 (debug or profile)
    String user_platform, // dimension3 (android/ios/fuchsia/linux/mac/windows)
    String devtools_platform, // dimension4 linux/android/mac/windows
    String devtools_chrome, // dimension5 Chrome version #
    String devtools_version, // dimension6 DevTools version #
    String ide_launched, // dimension7 Devtools launched (CLI, VSCode, Android)
    String flutter_client_id, // dimension8 Flutter tool client_id (~/.flutter).

    int raster_duration,
    int ui_duration,
  });

  @override
  external String get event_category;

  @override
  external String get event_label;

  @override
  external String get send_to;

  @override
  external int get value; // Positive number.

  @override
  external bool get non_interaction;

  @override
  external dynamic get custom_map;

  // Custom dimensions:
  external String get user_app;

  external String get user_build;

  external String get user_platform;

  external String get devtools_platform;

  external String get devtools_chrome;

  external String get devtools_version;

  external String get ide_launched;

  external String get flutter_client_id;

  // Custom metrics:
  external int get raster_duration;

  external int get ui_duration;
}

@JS()
@anonymous
class GtagExceptionDevTools extends GtagException {
  external factory GtagExceptionDevTools({
    String description,
    bool fatal,
    String user_app, // dimension1 (flutter or web)
    String user_build, // dimension2 (debug or profile)
    String user_platform, // dimension3 (android or ios)
    String devtools_platform, // dimension4 linux/android/mac/windows
    String devtools_chrome, // dimension5 Chrome version #
    String devtools_version, // dimension6 DevTools version #
    String ide_launched, // dimension7 IDE launched DevTools
    String flutter_client_id, // dimension8 Flutter tool clientId
  });

  @override
  external String get description; // Description of the error.
  @override
  external bool get fatal; // Fatal error.

  // Custom dimensions:
  external String get user_app;

  external String get user_build;

  external String get user_platform;

  external String get devtools_platform;

  external String get devtools_chrome;

  external String get devtools_version;

  external String get ide_launched;

  external String get flutter_client_id;
}

// Code to check if DevTools server is available, will only be true in release
// mode, debug mode will be set to false.
bool get isDevToolsServerAvailable => !isDebugBuild();

/// Helper to catch any server request which could fail we don't want to fail
/// because Analytics had a problem.
///
/// Returns HttpRequest or null (if server failure).
Future<HttpRequest> _request(String url) async {
  HttpRequest response;

  try {
    response = await HttpRequest.request(url, method: 'POST');
  } catch (_) {}

  return response;
}

void _logWarning(HttpRequest response, String apiType, [String respText]) {
  log(
    'HttpRequest $apiType failed status = ${response?.status}'
    '${respText != null ? ', responseText = $respText' : ''}',
    LogLevel.warning,
  );
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
Future<bool> get isFlutterGAEnabled async {
  bool enabled = false;

  if (isDevToolsServerAvailable) {
    final resp = await _request(server.apiGetFlutterGAEnabled);
    if (resp?.status == HttpStatus.ok) {
      // A return value of 'null' implies Flutter tool has never been run so
      // return false for Flutter GA enabled.
      final responseValue = json.decode(resp.responseText);
      enabled = responseValue == null ? false : responseValue;
    } else {
      _logWarning(resp, server.apiGetFlutterGAEnabled);
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
    if (await isFlutterGAEnabled) {
      final resp = await _request(server.apiGetFlutterGAClientId);
      if (resp?.status == HttpStatus.ok) {
        clientId = json.decode(resp.responseText);
        if (clientId == null) {
          // Requested value of 'null' (Flutter tool never ran). Server request
          // apiGetFlutterGAClientId should not happen because the
          // isFlutterGAEnabled test should have been false.
          log('${server.apiGetFlutterGAClientId} is null', LogLevel.warning);
        }
      } else {
        _logWarning(resp, server.apiGetFlutterGAClientId);
      }
    }
  }

  return clientId;
}

/// Requests all .devtools properties to be reset to their default values in the
/// file '~/.devtools'.
Future<void> resetDevToolsFile() async {
  if (isDevToolsServerAvailable) {
    final resp = await _request(server.apiResetDevTools);
    if (resp?.status == HttpStatus.ok) {
      assert(json.decode(resp.responseText));
    } else {
      _logWarning(resp, server.apiResetDevTools);
    }
  }
}

/// Request DevTools property value 'firstRun' (GA dialog) stored in the file
/// '~\.devtools'.
Future<bool> get isFirstRun async {
  bool firstRun = false;

  if (isDevToolsServerAvailable) {
    final resp = await _request(server.apiGetDevToolsFirstRun);
    if (resp?.status == HttpStatus.ok) {
      firstRun = json.decode(resp.responseText);
    } else {
      _logWarning(resp, server.apiGetDevToolsFirstRun);
    }
  }

  return firstRun;
}

bool _gaEnabled;

// Exposed function to JS via allowInterop.
bool gaEnabled() => _gaEnabled;

/// Request DevTools property value 'enabled' (GA enabled) stored in the file
/// '~\.devtools'.
Future<bool> get isEnabled async {
  if (_gaEnabled != null) return _gaEnabled;

  bool enabled = false;

  if (isDevToolsServerAvailable) {
    final resp = await _request(server.apiGetDevToolsEnabled);
    if (resp?.status == HttpStatus.ok) {
      enabled = json.decode(resp.responseText);
    } else {
      _logWarning(resp, server.apiGetDevToolsEnabled);
    }
  }
  _gaEnabled = enabled;

  return enabled;
}

/// Set the DevTools property 'enabled' (GA enabled) stored in the file
/// '~/.devtools'.
Future<void> setEnabled([bool value = true]) async {
  if (isDevToolsServerAvailable) {
    final resp = await _request(
      '${server.apiSetDevToolsEnabled}'
      '?${server.devToolsEnabledPropertyName}=$value',
    );
    if (resp?.status == HttpStatus.ok) {
      assert(json.decode(resp.responseText) == value);
      _gaEnabled = value;
    } else {
      _logWarning(resp, server.apiSetDevToolsEnabled, resp.responseText);
    }
  }
}

/// Set DevTools parameter value for the active survey (e.g. 'Q1-2020').
///
/// The value is stored in the file '~\.devtools'.
///
/// This method must be called before calling other survey related methods
/// ([isSurveyActionTaken], [setSurveyActionTaken], [surveyShownCount],
/// [incrementSurveyShownCount]). If the active survey is not set, warnings are
/// logged.
Future<bool> setActiveSurvey(String value) async {
  if (isDevToolsServerAvailable) {
    final resp = await _request('${server.apiSetActiveSurvey}'
        '?${server.activeSurveyName}=$value');
    if (resp?.status == HttpStatus.ok && json.decode(resp.responseText)) {
      return true;
    }
    if (resp?.status != HttpStatus.ok || !json.decode(resp.responseText)) {
      _logWarning(resp, server.apiSetActiveSurvey);
    }
  }
  return false;
}

/// Request DevTools property value 'surveyActionTaken' for the active survey.
///
/// The value is stored in the file '~\.devtools'.
///
/// Requires [setActiveSurvey] to have been called prior to calling this method.
Future<bool> get isSurveyActionTaken async {
  bool surveyActionTaken = false;

  if (isDevToolsServerAvailable) {
    final resp = await _request(server.apiGetSurveyActionTaken);
    if (resp?.status == HttpStatus.ok) {
      surveyActionTaken = json.decode(resp.responseText);
    } else {
      _logWarning(resp, server.apiGetSurveyActionTaken);
    }
  }

  return surveyActionTaken;
}

/// Set DevTools property value 'surveyActionTaken' for the active survey.
///
/// The value is stored in the file '~\.devtools'.
///
/// Requires [setActiveSurvey] to have been called prior to calling this method.
Future<void> setSurveyActionTaken() async {
  if (isDevToolsServerAvailable) {
    final resp = await _request(
      '${server.apiSetSurveyActionTaken}'
      '?${server.surveyActionTakenPropertyName}=true',
    );
    if (resp?.status != HttpStatus.ok || !json.decode(resp.responseText)) {
      _logWarning(resp, server.apiSetSurveyActionTaken, resp.responseText);
    }
  }
}

/// Request DevTools property value 'surveyShownCount' for the active survey.
///
/// The value is stored in the file '~\.devtools'.
///
/// Requires [setActiveSurvey] to have been called prior to calling this method.
Future<int> get surveyShownCount async {
  int surveyShownCount = 0;

  if (isDevToolsServerAvailable) {
    final resp = await _request(server.apiGetSurveyShownCount);
    if (resp?.status == HttpStatus.ok) {
      surveyShownCount = json.decode(resp.responseText);
    } else {
      _logWarning(resp, server.apiGetSurveyShownCount);
    }
  }

  return surveyShownCount;
}

/// Increment DevTools property value 'surveyShownCount' for the active survey.
///
/// The value is stored in the file '~\.devtools'.
///
/// Requires [setActiveSurvey] to have been called prior to calling this method.
Future<int> get incrementSurveyShownCount async {
  // Any failure will still return 0.
  int surveyShownCount = 0;

  if (isDevToolsServerAvailable) {
    final resp = await _request(server.apiIncrementSurveyShownCount);
    if (resp?.status == HttpStatus.ok) {
      surveyShownCount = json.decode(resp.responseText);
    } else {
      _logWarning(resp, server.apiIncrementSurveyShownCount);
    }
  }
  return surveyShownCount;
}

void screen(
  String screenName, [
  int value = 0,
]) {
  GTag.event(
    screenName,
    GtagEventDevTools(
      event_category: screenViewEvent,
      value: value,
      user_app: userAppType,
      user_build: userBuildType,
      user_platform: userPlatformType,
      devtools_platform: devtoolsPlatformType,
      devtools_chrome: devtoolsChrome,
      devtools_version: devtoolsVersion,
      ide_launched: ideLaunched,
      flutter_client_id: flutterClientId,
    ),
  );
}

void select(
  String screenName,
  String selectedItem, [
  int value = 0,
]) {
  GTag.event(
    screenName,
    GtagEventDevTools(
      event_category: selectEvent,
      event_label: selectedItem,
      value: value,
      user_app: userAppType,
      user_build: userBuildType,
      user_platform: userPlatformType,
      devtools_platform: devtoolsPlatformType,
      devtools_chrome: devtoolsChrome,
      devtools_version: devtoolsVersion,
      ide_launched: ideLaunched,
      flutter_client_id: flutterClientId,
    ),
  );
}

// Used only for Timeline Frame selection.
void selectFrame(
  String screenName,
  String selectedItem, [
  int rasterDuration, // Custom metric
  int uiDuration, // Custom metric
]) {
  GTag.event(
    screenName,
    GtagEventDevTools(
      event_category: selectEvent,
      event_label: selectedItem,
      raster_duration: rasterDuration,
      ui_duration: uiDuration,
      user_app: userAppType,
      user_build: userBuildType,
      user_platform: userPlatformType,
      devtools_platform: devtoolsPlatformType,
      devtools_chrome: devtoolsChrome,
      devtools_version: devtoolsVersion,
      ide_launched: ideLaunched,
      flutter_client_id: flutterClientId,
    ),
  );
}

String _lastGaError;

void error(
  String errorMessage,
  bool fatal,
) {
  // Don't keep recording same last error.
  if (_lastGaError == errorMessage) return;
  _lastGaError = errorMessage;

  GTag.exception(
    GtagExceptionDevTools(
      description: errorMessage,
      fatal: fatal,
      user_app: userAppType,
      user_build: userBuildType,
      user_platform: userPlatformType,
      devtools_platform: devtoolsPlatformType,
      devtools_chrome: devtoolsChrome,
      devtools_version: devtoolsVersion,
      ide_launched: ideLaunched,
      flutter_client_id: flutterClientId,
    ),
  );
}

////////////////////////////////////////////////////////////////////////////////
// Utilities to collect all platform and DevTools state for Analytics.
////////////////////////////////////////////////////////////////////////////////

// GA dimensions:
String _userAppType = ''; // dimension1
String _userBuildType = ''; // dimension2
String _userPlatformType = ''; // dimension3

String _devtoolsPlatformType =
    ''; // dimension4 MacIntel/Linux/Windows/Android_n
String _devtoolsChrome = ''; // dimension5 Chrome/n.n.n  or Crios/n.n.n

const String devtoolsVersion = devtools.version; //dimension6 n.n.n

String _ideLaunched = ''; // dimension7 IDE launched DevTools (VSCode, CLI, ...)

String _flutterClientId = ''; // dimension8 Flutter tool clientId.

String get userAppType => _userAppType;

set userAppType(String __userAppType) {
  _userAppType = __userAppType;
}

String get userBuildType => _userBuildType;

set userBuildType(String __userBuildType) {
  _userBuildType = __userBuildType;
}

String get userPlatformType => _userPlatformType;

set userPlatformType(String __userPlatformType) {
  _userPlatformType = __userPlatformType;
}

String get devtoolsPlatformType => _devtoolsPlatformType;

set devtoolsPlatformType(String __devtoolsPlatformType) {
  _devtoolsPlatformType = __devtoolsPlatformType;
}

String get devtoolsChrome => _devtoolsChrome;

set devtoolsChrome(String __devtoolsChrome) {
  _devtoolsChrome = __devtoolsChrome;
}

String get ideLaunched => _ideLaunched;

set ideLaunched(String __ideLaunched) {
  _ideLaunched = __ideLaunched;
}

String get flutterClientId => _flutterClientId;

set flutterClientId(String __flutterClientId) {
  _flutterClientId = __flutterClientId;
}

bool _analyticsComputed = false;

bool get isDimensionsComputed => _analyticsComputed;

void dimensionsComputed() {
  _analyticsComputed = true;
}

// Computes the running application.
Future<void> computeUserApplicationCustomGTagData() async {
  if (isDimensionsComputed) return;

  final isFlutter = await serviceManager.connectedApp.isFlutterApp;
  final isWebApp = await serviceManager.connectedApp.isDartWebApp;
  final isProfile = await serviceManager.connectedApp.isProfileBuild;

  if (isFlutter) {
    userPlatformType = (await serviceManager.service.isProtocolVersionSupported(
            supportedVersion: SemanticVersion(major: 3, minor: 24)))
        ? serviceManager.vm.operatingSystem
        : 'unknown';
  }

  if (isFlutter) {
    userAppType = appTypeFlutter;
  }
  if (isWebApp) {
    userAppType = appTypeWeb;
  }
  userBuildType = isProfile ? buildTypeProfile : buildTypeDebug;

  _analyticsComputed = true;
}

void exposeGaDevToolsEnabledToJs() {
  setProperty(window, 'gaDevToolsEnabled', allowInterop(gaEnabled));
}

@JS('getDevToolsPropertyID')
external String devToolsProperty();

@JS('hookupListenerForGA')
external void jsHookupListenerForGA();

Future<bool> get isAnalyticsAllowed async => await isEnabled;

void setAllowAnalytics() {
  setEnabled();
}

void setDontAllowAnalytics() {
  setEnabled(false);
}

/// Computes the DevTools application. Fills in the devtoolsPlatformType and
/// devtoolsChrome.
void computeDevToolsCustomGTagsData() {
  // Platform
  final String platform = window.navigator.platform;
  platform.replaceAll(' ', '_');
  devtoolsPlatformType = platform;

  final String appVersion = window.navigator.appVersion;
  final List<String> splits = appVersion.split(' ');
  final len = splits.length;
  for (int index = 0; index < len; index++) {
    final String value = splits[index];
    // Chrome or Chrome iOS
    if (value.startsWith(devToolsChromeName) ||
        value.startsWith(devToolsChromeIos)) {
      devtoolsChrome = value;
    } else if (value.startsWith('Android')) {
      // appVersion for Android is 'Android n.n.n'
      devtoolsPlatformType = '$devToolsPlatformTypeAndroid${splits[index + 1]}';
    } else if (value == devToolsChromeOS) {
      // Chrome OS will return a platform e.g., CrOS_Linux_x86_64
      devtoolsPlatformType = '${devToolsChromeOS}_$platform';
    }
  }
}

// Look at the query parameters '&ide=' and record in GA.
void computeDevToolsQueryParams() {
  ideLaunched = ideLaunchedCLI; // Default is Command Line launch.

  final Uri uri = Uri.parse(window.location.toString());
  final ideValue = uri.queryParameters[ideLaunchedQuery];
  if (ideValue != null) {
    ideLaunched = ideValue;
  }
}

void computeFlutterClientId() async {
  flutterClientId = await flutterGAClientID();
}

bool _computing = false;

int _stillWaiting = 0;
void waitForDimensionsComputed(String screenName) {
  Timer(const Duration(milliseconds: 100), () async {
    if (isDimensionsComputed) {
      screen(screenName);
    } else {
      if (_stillWaiting++ < 50) {
        waitForDimensionsComputed(screenName);
      } else {
        log('Cancel waiting for dimensions.', LogLevel.warning);
      }
    }
  });
}

// Loading screen from a hash code, can't collect GA (if enabled) until we have
// all the dimension data.
void setupAndGaScreen(String screenName) async {
  if (isGtagsEnabled()) {
    if (!isDimensionsComputed) {
      _stillWaiting++;
      waitForDimensionsComputed(screenName);
    } else {
      screen(screenName);
    }
  }
}

Future<void> setupDimensions() async {
  if (serviceManager.connectedApp != null &&
      isGtagsEnabled() &&
      !isDimensionsComputed &&
      !_computing) {
    _computing = true;
    // While spinning up DevTools first time wait until dimensions data is
    // available before first GA event sent.
    await computeUserApplicationCustomGTagData();
    computeDevToolsCustomGTagsData();
    computeDevToolsQueryParams();
    computeFlutterClientId();
    dimensionsComputed();
  }
}
