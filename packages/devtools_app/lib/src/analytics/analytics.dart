// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@JS()
library gtags;

// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:html';

import 'package:flutter/foundation.dart';
import 'package:js/js.dart';
import 'package:js/js_util.dart';

import '../../devtools.dart' as devtools show version;
import '../app.dart';
import '../config_specific/logger/logger.dart';
import '../config_specific/server/server.dart' as server;
import '../config_specific/url/url.dart';
import '../globals.dart';
import '../ui/gtags.dart';
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
external bool Function() get _isGtagsEnabled;

bool isGtagsEnabled() => _isGtagsEnabled?.call() ?? false;

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

ValueNotifier<bool> _gaEnabledNotifier = ValueNotifier(false);

ValueListenable<bool> get gaEnabledNotifier => _gaEnabledNotifier;

// Exposed function to JS via allowInterop.
bool gaEnabled() => _gaEnabledNotifier.value;

/// Request DevTools property value 'enabled' (GA enabled) stored in the file
/// '~\.devtools'.
Future<bool> isAnalyticsEnabled() async {
  _gaEnabledNotifier.value = await server.isAnalyticsEnabled();
  return _gaEnabledNotifier.value;
}

/// Set the DevTools property 'enabled' (GA enabled) stored in the file
/// '~/.devtools'.
Future<void> setAnalyticsEnabled([bool value = true]) async {
  final didSet = await server.setAnalyticsEnabled(value);
  if (didSet) {
    _gaEnabledNotifier.value = value;
  }
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

bool _computingDimensions = false;
bool _analyticsComputed = false;

bool _computingUserApplicationDimensions = false;
bool _userApplicationDimensionsComputed = false;

// Computes the running application.
Future<void> computeUserApplicationCustomGTagData() async {
  if (_userApplicationDimensionsComputed) return;

  assert(serviceManager.connectedApp.isFlutterAppNow != null);
  assert(serviceManager.connectedApp.isDartWebAppNow != null);
  assert(serviceManager.connectedApp.isProfileBuildNow != null);

  if (serviceManager.connectedApp.isFlutterAppNow) {
    userPlatformType = (await serviceManager.service.isProtocolVersionSupported(
            supportedVersion: SemanticVersion(major: 3, minor: 24)))
        ? serviceManager.vm.operatingSystem
        : 'unknown';
  }

  if (serviceManager.connectedApp.isFlutterAppNow) {
    userAppType = appTypeFlutter;
  }
  if (serviceManager.connectedApp.isDartWebAppNow) {
    userAppType = appTypeWeb;
  }
  userBuildType = serviceManager.connectedApp.isProfileBuildNow
      ? buildTypeProfile
      : buildTypeDebug;

  _analyticsComputed = true;
}

void exposeGaDevToolsEnabledToJs() {
  setProperty(window, 'gaDevToolsEnabled', allowInterop(gaEnabled));
}

@JS('getDevToolsPropertyID')
external String devToolsProperty();

@JS('hookupListenerForGA')
external void jsHookupListenerForGA();

Future<bool> get isAnalyticsAllowed async => await isAnalyticsEnabled();

void setAllowAnalytics() {
  setAnalyticsEnabled();
}

void setDontAllowAnalytics() {
  setAnalyticsEnabled(false);
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

  final queryParameters = loadQueryParams();
  final ideValue = queryParameters[ideLaunchedQuery];
  if (ideValue != null) {
    ideLaunched = ideValue;
  }
}

void computeFlutterClientId() async {
  flutterClientId = await server.flutterGAClientID();
}

int _stillWaiting = 0;
void waitForDimensionsComputed(String screenName) {
  Timer(const Duration(milliseconds: 100), () async {
    if (_analyticsComputed) {
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
    if (!_analyticsComputed) {
      _stillWaiting++;
      waitForDimensionsComputed(screenName);
    } else {
      screen(screenName);
    }
  }
}

void setupDimensions() {
  if (isGtagsEnabled() && !_analyticsComputed && !_computingDimensions) {
    _computingDimensions = true;
    computeDevToolsCustomGTagsData();
    computeDevToolsQueryParams();
    computeFlutterClientId();
    _analyticsComputed = true;
  }
}

Future<void> setupUserApplicationDimensions() async {
  if (serviceManager.connectedApp != null &&
      !_userApplicationDimensionsComputed &&
      !_computingUserApplicationDimensions) {
    _computingUserApplicationDimensions = true;
    await computeUserApplicationCustomGTagData();
    _userApplicationDimensionsComputed = true;
  }
}

Map<String, dynamic> generateSurveyQueryParameters() {
  const clientIdKey = 'ClientId';
  const ideKey = 'IDE';
  const fromKey = 'From';
  const internalKey = 'Internal';

  // TODO(https://github.com/flutter/devtools/issues/2475): fix url structure
  // Parsing the url via Uri.parse returns an incorrect value for fragment.
  // Grab the fragment value manually. The url will be of the form
  // http://127.0.0.1:9100/#/timeline?ide=IntelliJ-IDEA&uri=..., and we want the
  // part equal to '/timeline'.
  final url = window.location.toString();
  const fromValuePrefix = '#/';
  final startIndex = url.indexOf(fromValuePrefix);
  final endIndex = url.indexOf('?');
  final fromPage = url.substring(
    startIndex + fromValuePrefix.length,
    endIndex,
  );

  final clientId = flutterClientId;
  final internalValue = (!isExternalBuild).toString();

  return {
    clientIdKey: clientId,
    ideKey: ideLaunched,
    fromKey: fromPage,
    internalKey: internalValue,
  };
}
