// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@JS()
library gtags;

import 'package:js/js.dart';
import '../ui/ui_utils.dart';

/// For gtags API see https://developers.google.com/gtagjs/reference/api
/// For debugging install the Chrome Plugin "Google Analytics Debugger".

/// Analytic's DevTools Property ID 'UA-nnn'.
@JS('_GA_DEVTOOLS_PROPERTY')
external String get gaDevToolsPropertyTrackingID;

@JS('gtag')
external void _gTagCommandName(String command, String name, [dynamic params]);

@JS('gaCollectionAllowed')
external bool gaCollectionAllowed();

/// Google Analytics ready to collect.
@JS('isGaInitialized')
external bool isGaInitialized();

class GTag {
  static const String _event = 'event';
  static const String _exception = 'exception';

  /// Collect the analytic's event and its parameters.
  static void event(String eventName, GtagEvent gaEvent) {
    if (gaCollectionAllowed()) _gTagCommandName(_event, eventName, gaEvent);
  }

  static void exception(GtagException gaException) {
    if (gaCollectionAllowed())
      _gTagCommandName(_event, _exception, gaException);
  }
}

@JS()
@anonymous
class GtagEvent {
  external factory GtagEvent({
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
    String app_type, // dimension1 (flutter or web)
    // ignore: non_constant_identifier_names
    String build_type, // dimension2 (debug or profile)
    // ignore: non_constant_identifier_names
    String platform_type, // dimension3 (android or ios)
  });

  // ignore: non_constant_identifier_names
  external String get event_category;
  // ignore: non_constant_identifier_names
  external String get event_label;
  // ignore: non_constant_identifier_names
  external String get send_to;
  // ignore: non_constant_identifier_names
  external int get value; // Positive number.
  // ignore: non_constant_identifier_names
  external bool get non_interaction;
  // ignore: non_constant_identifier_names
  external dynamic get custom_map;

  // Custom dimensions:
  // ignore: non_constant_identifier_names
  external String get app_type;
  // ignore: non_constant_identifier_names
  external String get build_type;
  // ignore: non_constant_identifier_names
  external String get platform_type;
}

@JS()
@anonymous
class GtagException {
  external factory GtagException({
    String description,
    bool fatal,

    // ignore: non_constant_identifier_names
    String app_type, // dimension1 (flutter or web)
    // ignore: non_constant_identifier_names
    String build_type, // dimension2 (debug or profile)
    // ignore: non_constant_identifier_names
    String platform_type, // dimension3 (android or ios)
  });

  external String get description; // Description of the error.
  external bool get fatal; // Fatal error.
  // Custom dimensions:
  // ignore: non_constant_identifier_names
  external String get app_type;
  // ignore: non_constant_identifier_names
  external String get build_type;
  // ignore: non_constant_identifier_names
  external String get platform_type;
}

/// ****************************************************************************
/// *** DevTools Property Specific QA events and dimensions.                 ***
/// ****************************************************************************

// Type of events (event_category):
const String gaApplicationState = 'application_state'; // type, build, platform
const String gaScreenViewEvent = 'screen'; // Active screen (tab selected).
const String gaSelectEvent = 'select'; // User selected something.

const String gaOnError = 'onerror'; // Browser onError detected in DevTools
const String gaException = 'exception'; // Any Dart exception in DevTools

// DevTools GA screenNames
const String gaDevTools = 'main';
const String gaDebugger = 'debugger';
const String gaInspector = 'inspector';
const String gaMemory = 'memory';
const String gaTimeline = 'timeline';
const String gaLogging = 'loggimng';

// DevTools UI action selected (clicked).

// Main bar UX actions:
const String gaHotReload = 'hotReload';
const String gaHotRestart = 'hotRestart';
const String gaFeedback = 'feedback';

// Common UX actions:
const String gaPause = 'pause'; // Memory, Timeline, Debugger
const String gaResume = 'resume'; // Memory, Timeline, Debugger

// Inspector UX actions:
const String gaWidgetMode = 'widgetMode';
const String gaRefresh = 'refresh';
const String gaPerformanceOverlay = 'overlay';
const String gaDebugPaint = 'debugPaint';
const String gaPaintBaseline = 'paintBaseline';
const String gaSlowAnimation = 'slowAnimation';
const String gaRepaintRainbow = 'repaintRainbow';
const String gaDebugBanner = 'debugBanner';
const String gaTrackRebuilds = 'rebuilds';
const String gaIOS = 'iOS';
const String gaSelectWidgeMode = 'selectWidgeMode';

// Timeline UX actions:
const String gaTimelineFrame = 'frame'; // Frame selected in frame chart
const String gaTimelineFlame = 'flame'; // Select a UI/GPU flame

// Memory UX actions:
const String gaSnapshot = 'snapshot';
const String gaReset = 'reset';
const String gaGC = 'gc';
const String gaInspectClass = 'inspectClass'; // inspect a class from snapshot
const String gaInspectInstance = 'inspectInstance'; // inspect an instance
const String gaInspectData = 'inspectData'; // inspect data of the instance

// Debugger UX actions:
const String gaOpenShortcut = 'openShortcut';
const String gaStepIn = 'stepIn';
const String gaStepOver = 'stepOver';
const String gaStepOut = 'stepOut';
const String gaBP = 'bp';
const String gaUnhandledExceptions = 'unhandledExceptions';
const String gaAllExceptions = 'allExceptions';

// Logging UX actions:
const String gaClearLogs = 'clearLogs';

void gaScreen(String screenName, [int value = 0]) => GTag.event(
    screenName,
    GtagEvent(
        event_category: gaScreenViewEvent,
        value: value,
        app_type: userAppType,
        build_type: userBuildType,
        platform_type: userPlatformType));

void gaSelect(String screenName, String selectedItem, [int value = 0]) =>
    GTag.event(
        screenName,
        GtagEvent(
            event_category: gaSelectEvent,
            event_label: selectedItem,
            value: value,
            app_type: userAppType,
            build_type: userBuildType,
            platform_type: userPlatformType));

void gaError(String errorMessage, bool fatal) => GTag.exception(GtagException(
    description: errorMessage,
    fatal: fatal,
    app_type: userAppType,
    build_type: userBuildType,
    platform_type: userPlatformType));

// Dimensions1 AppType values:
const String gaAppTypeFlutter = 'flutter';
const String gaAppTypeWeb = 'web';
// Dimensions2 BuildType values:
const String gaBuildTypeDebug = 'debug';
const String gaBuildTypeProfile = 'profile';
// Dimensions3 PlatformType values:
const String gaPlatformTypeAndroid = 'android';
const String gaPlatformTypeIOS = 'ios';
