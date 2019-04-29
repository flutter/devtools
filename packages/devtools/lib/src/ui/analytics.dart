// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@JS()
library gtags;

import 'dart:async';
import 'dart:html' as html;

import 'package:devtools/devtools.dart' as devtools show version;
import 'package:js/js.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import '../eval_on_dart_library.dart';
import '../globals.dart';
import '../ui/gtags.dart';

// Dimensions1 AppType values:
const String appTypeFlutter = 'flutter';
const String appTypeWeb = 'web';
// Dimensions2 BuildType values:
const String buildTypeDebug = 'debug';
const String buildTypeProfile = 'profile';
// Dimensions3 PlatformType values:
const String platformTypeAndroid = 'android_flutter';
const String platformTypeIOS = 'ios_flutter';
const String platformTypeFuchsia = 'fuchsia';
const String platformTypeLinux = 'linux';
const String platformTypeMac = 'mac';
const String platformTypeWindows = 'windows';
// Dimension4 devToolsPlatformType values:
const String devToolsPlatformTypeMac = 'MacIntel';
const String devToolsPlatformTypeLinux = 'Linux';
const String devToolsPlatformTypeWindows = 'Windows';
// Start with Android_n.n.n
const String devToolsPlatformTypeAndroid = 'Android_';
// Dimension5 devToolsChrome starts with
const String devToolsChrome = 'Chrome/'; // starts with and ends with n.n.n
const String devToolsChromeIos = 'Crios/'; // starts with and ends with n.n.n
// Dimension6 devToolsVersion

@JS('gtagsEnabled')
external bool isGtagsEnabled();

@JS('getDevToolsPropertyID')
external String devToolsProperty();

@JS('_initializeGA')
external void initializeGA();

@JS('gaStorageCollect')
external String storageCollectValue();

@JS('gaStorageDontCollect')
external String storageDontCollectValue();

bool isAnalyticsAllowed() =>
    html.window.localStorage[devToolsProperty()] == storageCollectValue();

void setAllowAnalytics() {
  html.window.localStorage[devToolsProperty()] = storageCollectValue();
}

void setDontAllowAnalytics() {
  html.window.localStorage[devToolsProperty()] = storageDontCollectValue();
}

@JS()
@anonymous
class GtagEventDevTools extends GtagEvent {
  external factory GtagEventDevTools({
    // ignore: non_constant_identifier_names
    String event_category,
    // ignore: non_constant_identifier_names
    String event_label, // Event e.g., gaScreenViewEvent, gaSelectEvent, etc.
    // ignore: non_constant_identifier_names
    String send_to, // UA ID of target GA property to receive event data.

    int value,

    // ignore: non_constant_identifier_names
    bool non_interaction,

    // ignore: non_constant_identifier_names
    dynamic custom_map,

    // ignore: non_constant_identifier_names
    String user_app, // dimension1 (flutter or web)
    // ignore: non_constant_identifier_names
    String user_build, // dimension2 (debug or profile)
    // ignore: non_constant_identifier_names
    String user_platform, // dimension3 (android/ios/fuchsia/linux/mac/windows)
    // ignore: non_constant_identifier_names
    String devtools_platform, // dimension4 linux/android/mac/windows
    // ignore: non_constant_identifier_names
    String devtools_chrome, // dimension5 Chrome version #
    // ignore: non_constant_identifier_names
    String devtools_version, // dimension6 DevTools version #

    // ignore: non_constant_identifier_names
    int gpu_duration,
    // ignore: non_constant_identifier_names
    int ui_duration,
  });

  @override
  // ignore: non_constant_identifier_names
  external String get event_category;
  @override
  // ignore: non_constant_identifier_names
  external String get event_label;
  @override
  // ignore: non_constant_identifier_names
  external String get send_to;
  @override
  // ignore: non_constant_identifier_names
  external int get value; // Positive number.
  @override
  // ignore: non_constant_identifier_names
  external bool get non_interaction;
  @override
  // ignore: non_constant_identifier_names
  external dynamic get custom_map;

  // Custom dimensions:
  // ignore: non_constant_identifier_names
  external String get user_app;
  // ignore: non_constant_identifier_names
  external String get user_build;
  // ignore: non_constant_identifier_names
  external String get user_platform;
  // ignore: non_constant_identifier_names
  external String get devtools_platform;
  // ignore: non_constant_identifier_names
  external String get devtools_chrome;
  // ignore: non_constant_identifier_names
  external String get devtools_version;

  // Custom metrics:
  // ignore: non_constant_identifier_names
  external int get gpu_duration;
  // ignore: non_constant_identifier_names
  external int get ui_duration;
}

@JS()
@anonymous
class GtagExceptionDevTools extends GtagException {
  external factory GtagExceptionDevTools({
    String description,
    bool fatal,

    // ignore: non_constant_identifier_names
    String user_app, // dimension1 (flutter or web)
    // ignore: non_constant_identifier_names
    String user_build, // dimension2 (debug or profile)
    // ignore: non_constant_identifier_names
    String user_platform, // dimension3 (android or ios)
    // ignore: non_constant_identifier_names
    String devtools_platform, // dimension4 linux/android/mac/windows
    // ignore: non_constant_identifier_names
    String devtools_chrome, // dimension5 Chrome version #
    // ignore: non_constant_identifier_names
    String devtools_version, // dimension6 DevTools version #
  });

  @override
  external String get description; // Description of the error.
  @override
  external bool get fatal; // Fatal error.

  // Custom dimensions:
  // ignore: non_constant_identifier_names
  external String get user_app;
  // ignore: non_constant_identifier_names
  external String get user_build;
  // ignore: non_constant_identifier_names
  external String get user_platform;
  // ignore: non_constant_identifier_names
  external String get devtools_platform;
  // ignore: non_constant_identifier_names
  external String get devtools_chrome;
  // ignore: non_constant_identifier_names
  external String get devtools_version;
}

// Type of events (event_category):
const String applicationEvent = 'application'; // visible/hidden
const String screenViewEvent = 'screen'; // Active screen (tab selected).
const String selectEvent = 'select'; // User selected something.

const String errorError = 'onerror'; // Browser onError detected in DevTools
const String exceptionEvent = 'exception'; // Any Dart exception in DevTools

// DevTools GA screenNames:

// GA events not associated with a any screen e.g., hotReload, hotRestart, etc
const String devToolsMain = 'main';
const String debugger = 'debugger';
const String inspector = 'inspector';
const String logging = 'logging';
const String memory = 'memory';
const String performance = 'performance';
const String timeline = 'timeline';

// DevTools UI action selected (clicked).

// Main bar UX actions:
const String hotReload = 'hotReload';
const String hotRestart = 'hotRestart';
const String feedback = 'feedback';

// Common UX actions:
const String pause = 'pause'; // Memory, Timeline, Debugger
const String resume = 'resume'; // Memory, Timeline, Debugger

// Inspector UX actions:
const String widgetMode = 'widgetMode';
const String refresh = 'refresh';
const String performanceOverlay = 'performanceOverlay';
const String debugPaint = 'debugPaint';
const String paintBaseline = 'paintBaseline';
const String slowAnimation = 'slowAnimation';
const String repaintRainbow = 'repaintRainbow';
const String debugBanner = 'debugBanner';
const String trackRebuilds = 'trackRebuilds';
const String toggleIoS = 'iOS';
const String selectWidgetMode = 'selectWidgetMode';

// Timeline UX actions:
const String timelineFrame = 'frame'; // Frame selected in frame chart
const String timelineFlameGpu = 'flameGPU'; // Selected a GPU flame
const String timelineFlameUi = 'flameUI'; // Selected a UI flame

// Memory UX actions:
const String snapshot = 'snapshot';
const String reset = 'reset';
const String gC = 'gc';
const String inspectClass = 'inspectClass'; // inspect a class from snapshot
const String inspectInstance = 'inspectInstance'; // inspect an instance
const String inspectData = 'inspectData'; // inspect data of the instance

// Debugger UX actions:
const String openShortcut = 'openShortcut';
const String stepIn = 'stepIn';
const String stepOver = 'stepOver';
const String stepOut = 'stepOut';
const String bP = 'bp';
const String unhandledExceptions = 'unhandledExceptions';
const String allExceptions = 'allExceptions';

// Logging UX actions:
const String clearLogs = 'clearLogs';

void _screen(
  String screenName, [
  int value = 0,
]) {
  GTag.event(
      screenName,
      GtagEventDevTools(
          event_category: screenViewEvent,
          value: value,
          user_app: _userAppType,
          user_build: _userBuildType,
          user_platform: _userPlatformType,
          devtools_platform: _devtoolsPlatformType,
          devtools_chrome: _devtoolsChrome,
          devtools_version: devtoolsVersion));
}

void screen(
  String screenName, [
  int value = 0,
]) {
  if (!isDimensionsComputed) {
    // While spinning up DevTools first time wait until dimensions data is
    // available before first GA event sent.
    Timer(const Duration(milliseconds: 1000), () {
      computeUserApplicationCustomGTagData();
      _screen(screenName, value);
    });
  } else
    _screen(screenName, value);
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
          user_app: _userAppType,
          user_build: _userBuildType,
          user_platform: _userPlatformType,
          devtools_platform: _devtoolsPlatformType,
          devtools_chrome: _devtoolsChrome,
          devtools_version: devtoolsVersion));
}

// Used only for Timeline Frame selection.
void selectFrame(
  String screenName,
  String selectedItem, [
  int gpuDuration, // Custom metric
  int uiDuration, // Custom metric
]) {
  GTag.event(
      screenName,
      GtagEventDevTools(
          event_category: selectEvent,
          event_label: selectedItem,
          gpu_duration: gpuDuration,
          ui_duration: uiDuration,
          user_app: _userAppType,
          user_build: _userBuildType,
          user_platform: _userPlatformType,
          devtools_platform: _devtoolsPlatformType,
          devtools_chrome: _devtoolsChrome,
          devtools_version: devtoolsVersion));
}

String _lastGaError;

void error(
  String errorMessage,
  bool fatal,
) {
  // Don't keep recording same last error.
  if (_lastGaError == errorMessage) return;
  _lastGaError = errorMessage;

  GTag.exception(GtagExceptionDevTools(
      description: errorMessage,
      fatal: fatal,
      user_app: _userAppType,
      user_build: _userBuildType,
      user_platform: _userPlatformType,
      devtools_platform: _devtoolsPlatformType,
      devtools_chrome: _devtoolsChrome,
      devtools_version: devtoolsVersion));
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

String get userAppType {
  if (!isDimensionsComputed) computeUserApplicationCustomGTagData();
  return _userAppType;
}

String get userBuildType {
  if (!isDimensionsComputed) computeUserApplicationCustomGTagData();
  return _userBuildType;
}

String get userPlatformType {
  if (!isDimensionsComputed) computeUserApplicationCustomGTagData();
  return _userPlatformType;
}

String get devtoolsPlatformType {
  if (!isDimensionsComputed) computeUserApplicationCustomGTagData();
  return _devtoolsPlatformType;
}

String get devtoolsChrome {
  if (!isDimensionsComputed) computeUserApplicationCustomGTagData();
  return _devtoolsChrome;
}

bool _analyticsComputed = false;
bool get isDimensionsComputed => _analyticsComputed;

/// Computes the DevTools application. Fills in the devtoolsPlatformType and
/// devtoolsChrome.
void _computeDevToolsCustomGTagsData() {
  // Platform
  final String platform = html.window.navigator.platform;
  platform.replaceAll(' ', '_');
  _devtoolsPlatformType = platform;

  final String appVersion = html.window.navigator.appVersion;
  final List<String> splits = appVersion.split(' ');
  final len = splits.length;
  for (int index = 0; index < len; index++) {
    final String value = splits[index];
    // Chrome or Chrome iOS
    if (value.startsWith(devToolsChrome) ||
        value.startsWith(devToolsChromeIos)) {
      _devtoolsChrome = value;
    } else if (value.startsWith('Android')) {
      // appVersion for Android is 'Android n.n.n'
      _devtoolsPlatformType =
          '$devToolsPlatformTypeAndroid${splits[index + 1]}';
    }
  }
}

// Computes the running application.
void computeUserApplicationCustomGTagData() async {
  if (_analyticsComputed) return;

  final isFlutter = await serviceManager.connectedApp.isFlutterApp;
  final isWebApp = await serviceManager.connectedApp.isFlutterWebApp;
  final isProfile = await serviceManager.connectedApp.isProfileBuild;
  final isAnyFlutterApp = await serviceManager.connectedApp.isAnyFlutterApp;

  if (isFlutter) {
    // Compute the Flutter platform for the user's running application.
    final VmService vmService = serviceManager.service;
    final io = EvalOnDartLibrary(['dart:io'], vmService);

    // eval user's Platform for all possible values.
    final android = await io.eval('Platform.isAndroid', isAlive: null);
    final iOS = await io.eval('Platform.isIOS', isAlive: null);
    final fuchsia = await io.eval('Platform.isFuchsia', isAlive: null);
    final linux = await io.eval('Platform.isLinux', isAlive: null);
    final macOS = await io.eval('Platform.isMacOS', isAlive: null);
    final windows = await io.eval('Platform.isWindows', isAlive: null);

    if (android.valueAsString == 'true')
      _userPlatformType = platformTypeAndroid;
    else if (iOS.valueAsString == 'true')
      _userPlatformType = platformTypeIOS;
    else if (fuchsia.valueAsString == 'true')
      _userPlatformType = platformTypeFuchsia;
    else if (linux.valueAsString == 'true')
      _userPlatformType = platformTypeLinux;
    else if (macOS.valueAsString == 'true')
      _userPlatformType = platformTypeMac;
    else if (windows.valueAsString == 'true')
      _userPlatformType = platformTypeWindows;
  }

  if (isAnyFlutterApp) {
    if (isFlutter) _userAppType = appTypeFlutter;
    if (isWebApp) _userAppType = appTypeWeb;
  }
  _userBuildType = isProfile ? buildTypeProfile : buildTypeDebug;

  _computeDevToolsCustomGTagsData();

  _analyticsComputed = true;
}
