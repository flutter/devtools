// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@JS()
library gtags;

import 'dart:async';
import 'package:js/js.dart';

import '../ui/gtags.dart';
import '../ui/ui_utils.dart';

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
const String memory = 'memory';
const String timeline = 'timeline';
const String logging = 'logging';

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
const String iOS = 'iOS';
const String selectWidgetMode = 'selectWidgetMode';

// Timeline UX actions:
const String timelineFrame = 'frame'; // Frame selected in frame chart
const String timelineFlame = 'flame'; // Select a UI/GPU flame

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
          user_app: userAppType,
          user_build: userBuildType,
          user_platform: userPlatformType,
          devtools_platform: devtoolsPlatformType,
          devtools_chrome: devtoolsChrome,
          devtools_version: devtoolsVersion));
}

void screen(
  String screenName, [
  int value = 0,
]) {
  if (!isDimensionsComputed) {
    // This can happening while spinning up DevTools first time wait until our
    // dimensions data is available before fir GA event sent.
    Timer(const Duration(milliseconds: 500), () {
      computeApplicationState();
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
          user_app: userAppType,
          user_build: userBuildType,
          user_platform: userPlatformType,
          devtools_platform: devtoolsPlatformType,
          devtools_chrome: devtoolsChrome,
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
      user_app: userAppType,
      user_build: userBuildType,
      user_platform: userPlatformType,
      devtools_platform: devtoolsPlatformType,
      devtools_chrome: devtoolsChrome,
      devtools_version: devtoolsVersion));
}
