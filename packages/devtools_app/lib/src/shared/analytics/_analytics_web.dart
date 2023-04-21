// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@JS()
library gtags;

// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:html';

import 'package:js/js.dart';
import 'package:logging/logging.dart';

import '../../../devtools.dart' as devtools show version;
import '../config_specific/server/server.dart' as server;
import '../config_specific/url/url.dart';
import '../globals.dart';
import '../primitives/url_utils.dart';
import '../ui/gtags.dart';
import 'analytics_common.dart';
import 'constants.dart' as gac;
import 'metrics.dart';

// Dimensions1 AppType values:
const String appTypeFlutter = 'flutter';
const String appTypeWeb = 'web';
const String appTypeFlutterWeb = 'flutter_web';
const String appTypeDartCLI = 'dart_cli';
// Dimensions2 BuildType values:
const String buildTypeDebug = 'debug';
const String buildTypeProfile = 'profile';
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

final _log = Logger('_analytics_web');

@JS('initializeGA')
external void initializeGA();

@JS()
@anonymous
class GtagEventDevTools extends GtagEvent {
  // TODO(kenz): try to make this accept a JSON map of extra parameters rather
  // than a fixed list of fields. See
  // https://github.com/flutter/devtools/pull/3281#discussion_r692376353.
  external factory GtagEventDevTools({
    String? event_category,
    String? event_label, // Event e.g., gaScreenViewEvent, gaSelectEvent, etc.
    String? send_to, // UA ID of target GA property to receive event data.

    int value,
    bool non_interaction,
    // This code is going away so not worth cleaning up to be free of dynamic.
    // ignore: avoid-dynamic
    dynamic custom_map,

    // NOTE: Do not reorder any of these. Order here must match the order in the
    // Google Analytics console.

    String? user_app, // dimension1 (flutter or web)
    String? user_build, // dimension2 (debug or profile)
    String? user_platform, // dimension3 (android/ios/fuchsia/linux/mac/windows)
    String? devtools_platform, // dimension4 linux/android/mac/windows
    String? devtools_chrome, // dimension5 Chrome version #
    String? devtools_version, // dimension6 DevTools version #
    String? ide_launched, // dimension7 Devtools launched (CLI, VSCode, Android)
    String?
        flutter_client_id, // dimension8 Flutter tool client_id (~/.flutter).
    String? is_external_build, // dimension9 External build or google3
    String? is_embedded, // dimension10 Whether devtools is embedded
    String? g3_username, // dimension11 g3 username (null for external users)

    // Performance screen metrics. See [PerformanceScreenMetrics].
    int? ui_duration_micros, // metric1
    int? raster_duration_micros, // metric2
    int? shader_compilation_duration_micros, // metric3
    // Profiler screen metrics. See [ProfilerScreenMetrics].
    int? cpu_sample_count, // metric4
    int? cpu_stack_depth, // metric5
    // Performance screen metric. See [PerformanceScreenMetrics].
    int? trace_event_count, // metric6
    // Memory screen metric. See [MemoryScreenMetrics].
    int? heap_diff_objects_before, // metric7
    int? heap_diff_objects_after, // metric8
    int? heap_objects_total, // metric9
    int? root_set_count, // metric10
    int? row_count, // metric11
    int? inspector_tree_controller_id, // metric12
  });

  @override
  external String? get event_category;

  @override
  external String? get event_label;

  @override
  external String? get send_to;

  @override
  external int get value; // Positive number.

  @override
  external bool get non_interaction;

  @override
  external Object get custom_map;

  // Custom dimensions:
  external String? get user_app;

  external String? get user_build;

  external String? get user_platform;

  external String? get devtools_platform;

  external String? get devtools_chrome;

  external String? get devtools_version;

  external String? get ide_launched;

  external String? get flutter_client_id;

  external String? get is_external_build;

  external String? get is_embedded;

  external String? get g3_username;

  // Custom metrics:
  external int? get ui_duration_micros;

  external int? get raster_duration_micros;

  external int? get shader_compilation_duration_micros;

  external int? get cpu_sample_count;

  external int? get cpu_stack_depth;

  external int? get trace_event_count;

  external int? get heap_diff_objects_before;

  external int? get heap_diff_objects_after;

  external int? get heap_objects_total;
}

// This cannot be a factory constructor in the [GtagEventDevTools] class due to
// https://github.com/dart-lang/sdk/issues/46967.
GtagEventDevTools _gtagEvent({
  String? event_category,
  String? event_label,
  String? send_to,
  bool non_interaction = false,
  int value = 0,
  ScreenAnalyticsMetrics? screenMetrics,
}) {
  return GtagEventDevTools(
    event_category: event_category,
    event_label: event_label,
    send_to: send_to,
    non_interaction: non_interaction,
    value: value,
    user_app: userAppType,
    user_build: userBuildType,
    user_platform: userPlatformType,
    devtools_platform: devtoolsPlatformType,
    devtools_chrome: devtoolsChrome,
    devtools_version: devtoolsVersion,
    ide_launched: ideLaunched,
    flutter_client_id: flutterClientId,
    is_external_build: isExternalBuild.toString(),
    is_embedded: ideTheme.embed.toString(),
    g3_username: devToolsExtensionPoints.username(),
    // [PerformanceScreenMetrics]
    ui_duration_micros: screenMetrics is PerformanceScreenMetrics
        ? screenMetrics.uiDuration?.inMicroseconds
        : null,
    raster_duration_micros: screenMetrics is PerformanceScreenMetrics
        ? screenMetrics.rasterDuration?.inMicroseconds
        : null,
    shader_compilation_duration_micros:
        screenMetrics is PerformanceScreenMetrics
            ? screenMetrics.shaderCompilationDuration?.inMicroseconds
            : null,
    trace_event_count: screenMetrics is PerformanceScreenMetrics
        ? screenMetrics.traceEventCount
        : null,
    // [ProfilerScreenMetrics]
    cpu_sample_count: screenMetrics is ProfilerScreenMetrics
        ? screenMetrics.cpuSampleCount
        : null,
    cpu_stack_depth: screenMetrics is ProfilerScreenMetrics
        ? screenMetrics.cpuStackDepth
        : null,
    // [MemoryScreenMetrics]
    heap_diff_objects_before: screenMetrics is MemoryScreenMetrics
        ? screenMetrics.heapDiffObjectsBefore
        : null,
    heap_diff_objects_after: screenMetrics is MemoryScreenMetrics
        ? screenMetrics.heapDiffObjectsAfter
        : null,
    heap_objects_total: screenMetrics is MemoryScreenMetrics
        ? screenMetrics.heapObjectsTotal
        : null,
    // [InspectorScreenMetrics]
    root_set_count: screenMetrics is InspectorScreenMetrics
        ? screenMetrics.rootSetCount
        : null,
    row_count:
        screenMetrics is InspectorScreenMetrics ? screenMetrics.rowCount : null,
    inspector_tree_controller_id: screenMetrics is InspectorScreenMetrics
        ? screenMetrics.inspectorTreeControllerId
        : null,
  );
}

// This cannot be a factory constructor in the [GtagExceptionDevTools] class due to
// https://github.com/dart-lang/sdk/issues/46967.
GtagExceptionDevTools _gtagException(
  String errorMessage, {
  bool fatal = false,
  ScreenAnalyticsMetrics? screenMetrics,
}) {
  return GtagExceptionDevTools(
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
    is_external_build: isExternalBuild.toString(),
    is_embedded: ideTheme.embed.toString(),
    g3_username: devToolsExtensionPoints.username(),
    // [PerformanceScreenMetrics]
    ui_duration_micros: screenMetrics is PerformanceScreenMetrics
        ? screenMetrics.uiDuration?.inMicroseconds
        : null,
    raster_duration_micros: screenMetrics is PerformanceScreenMetrics
        ? screenMetrics.rasterDuration?.inMicroseconds
        : null,
    trace_event_count: screenMetrics is PerformanceScreenMetrics
        ? screenMetrics.traceEventCount
        : null,
    shader_compilation_duration_micros:
        screenMetrics is PerformanceScreenMetrics
            ? screenMetrics.shaderCompilationDuration?.inMicroseconds
            : null,
    // [ProfilerScreenMetrics]
    cpu_sample_count: screenMetrics is ProfilerScreenMetrics
        ? screenMetrics.cpuSampleCount
        : null,
    cpu_stack_depth: screenMetrics is ProfilerScreenMetrics
        ? screenMetrics.cpuStackDepth
        : null,
    // [MemoryScreenMetrics]
    heap_diff_objects_before: screenMetrics is MemoryScreenMetrics
        ? screenMetrics.heapDiffObjectsBefore
        : null,
    heap_diff_objects_after: screenMetrics is MemoryScreenMetrics
        ? screenMetrics.heapDiffObjectsAfter
        : null,
    heap_objects_total: screenMetrics is MemoryScreenMetrics
        ? screenMetrics.heapObjectsTotal
        : null,
  );
}

@JS()
@anonymous
class GtagExceptionDevTools extends GtagException {
  external factory GtagExceptionDevTools({
    String? description,
    bool fatal,

    // NOTE: Do not reorder any of these. Order here must match the order in the
    // Google Analytics console.

    String? user_app, // dimension1 (flutter or web)
    String? user_build, // dimension2 (debug or profile)
    String? user_platform, // dimension3 (android or ios)
    String? devtools_platform, // dimension4 linux/android/mac/windows
    String? devtools_chrome, // dimension5 Chrome version #
    String? devtools_version, // dimension6 DevTools version #
    String? ide_launched, // dimension7 IDE launched DevTools
    String? flutter_client_id, // dimension8 Flutter tool clientId
    String? is_external_build, // dimension9 External build or google3
    String? is_embedded, // dimension10 Whether devtools is embedded
    String? g3_username, // dimension11 g3 username (null for external users)

    // Performance screen metrics. See [PerformanceScreenMetrics].
    int? ui_duration_micros, // metric1
    int? raster_duration_micros, // metric2
    int? shader_compilation_duration_micros, // metric3
    // Profiler screen metrics. See [ProfilerScreenMetrics].
    int? cpu_sample_count, // metric4
    int? cpu_stack_depth, // metric5
    // Performance screen metric. See [PerformanceScreenMetrics].
    int? trace_event_count, // metric6
    // Memory screen metric. See [MemoryScreenMetrics].
    int? heap_diff_objects_before, // metric7
    int? heap_diff_objects_after, // metric8
    int? heap_objects_total, // metric9
  });

  @override
  external String? get description; // Description of the error.
  @override
  external bool get fatal; // Fatal error.

  // Custom dimensions:
  external String? get user_app;

  external String? get user_build;

  external String? get user_platform;

  external String? get devtools_platform;

  external String? get devtools_chrome;

  external String? get devtools_version;

  external String? get ide_launched;

  external String? get flutter_client_id;

  external String? get is_external_build;

  external String? get is_embedded;

  external String? get g3_username;

  // Custom metrics:
  external int? get ui_duration_micros;

  external int? get raster_duration_micros;

  external int? get shader_compilation_duration_micros;

  external int? get cpu_sample_count;

  external int? get cpu_stack_depth;

  external int? get trace_event_count;

  external int? get heap_diff_objects_before;

  external int? get heap_diff_objects_after;

  external int? get heap_objects_total;
}

/// Request DevTools property value 'enabled' (GA enabled) stored in the file
/// '~/.flutter-devtools/.devtools'.
Future<bool> isAnalyticsEnabled() async {
  return await server.isAnalyticsEnabled();
}

/// Set the DevTools property 'enabled' (GA enabled) stored in the file
/// '~/flutter-devtools/.devtools'.
Future<bool> setAnalyticsEnabled(bool value) async {
  return await server.setAnalyticsEnabled(value);
}

void screen(
  String screenName, [
  int value = 0,
]) {
  _log.fine('Event: Screen(screenName:$screenName, value:$value)');
  GTag.event(
    screenName,
    gaEventProvider: () => _gtagEvent(
      event_category: gac.screenViewEvent,
      value: value,
      send_to: gaDevToolsPropertyId(),
    ),
  );
}

String _operationKey(String screenName, String timedOperation) {
  return '$screenName-$timedOperation';
}

final _timedOperationsInProgress = <String, DateTime>{};

// Use this method coupled with `timeEnd` when an operation cannot be timed in
// a callback, but rather needs to be timed instead at two disjoint start and
// end marks.
void timeStart(String screenName, String timedOperation) {
  final startTime = DateTime.now();
  final operationKey = _operationKey(
    screenName,
    timedOperation,
  );
  _timedOperationsInProgress[operationKey] = startTime;
}

// Use this method coupled with `timeStart` when an operation cannot be timed in
// a callback, but rather needs to be timed instead at two disjoint start and
// end marks.
void timeEnd(
  String screenName,
  String timedOperation, {
  ScreenAnalyticsMetrics Function()? screenMetricsProvider,
}) {
  final endTime = DateTime.now();
  final operationKey = _operationKey(
    screenName,
    timedOperation,
  );
  final startTime = _timedOperationsInProgress.remove(operationKey);
  assert(startTime != null);
  if (startTime == null) {
    _log.warning(
      'Could not time operation "$timedOperation" because a) `timeEnd` was '
      'called before `timeStart` or b) the `screenName` and `timedOperation`'
      'parameters for the `timeStart` and `timeEnd` calls do not match.',
    );
    return;
  }
  final durationMicros =
      endTime.microsecondsSinceEpoch - startTime.microsecondsSinceEpoch;
  _timing(
    screenName,
    timedOperation,
    durationMicros: durationMicros,
    screenMetrics:
        screenMetricsProvider != null ? screenMetricsProvider() : null,
  );
}

void cancelTimingOperation(String screenName, String timedOperation) {
  final operationKey = _operationKey(
    screenName,
    timedOperation,
  );
  final operation = _timedOperationsInProgress.remove(operationKey);
  assert(
    operation != null,
    'The operation cannot be cancelled because it does not exist.',
  );
}

// Use this when a synchronous operation can be timed in a callback.
void timeSync(
  String screenName,
  String timedOperation, {
  required void Function() syncOperation,
  ScreenAnalyticsMetrics Function()? screenMetricsProvider,
}) {
  final startTime = DateTime.now();
  try {
    syncOperation();
  } catch (e, st) {
    // Do not send the timing analytic to GA if the operation failed.
    _log.warning(
      'Could not time sync operation "$timedOperation" '
      'because an exception was thrown:\n$e\n$st',
    );
    rethrow;
  }
  final endTime = DateTime.now();
  final durationMicros =
      endTime.microsecondsSinceEpoch - startTime.microsecondsSinceEpoch;
  _timing(
    screenName,
    timedOperation,
    durationMicros: durationMicros,
    screenMetrics:
        screenMetricsProvider != null ? screenMetricsProvider() : null,
  );
}

// Use this when an asynchronous operation can be timed in a callback.
Future<void> timeAsync(
  String screenName,
  String timedOperation, {
  required Future<void> Function() asyncOperation,
  ScreenAnalyticsMetrics Function()? screenMetricsProvider,
}) async {
  final startTime = DateTime.now();
  try {
    await asyncOperation();
  } catch (e, st) {
    // Do not send the timing analytic to GA if the operation failed.
    _log.warning(
      'Could not time async operation "$timedOperation" '
      'because an exception was thrown:\n$e\n$st',
    );
    rethrow;
  }
  final endTime = DateTime.now();
  final durationMicros =
      endTime.microsecondsSinceEpoch - startTime.microsecondsSinceEpoch;
  _timing(
    screenName,
    timedOperation,
    durationMicros: durationMicros,
    screenMetrics:
        screenMetricsProvider != null ? screenMetricsProvider() : null,
  );
}

void _timing(
  String screenName,
  String timedOperation, {
  required int durationMicros,
  ScreenAnalyticsMetrics? screenMetrics,
}) {
  _log.fine(
    'Event: _timing('
    'screenName:$screenName, '
    'timedOperation:$timedOperation, '
    'durationMicros:$durationMicros)',
  );
  GTag.event(
    screenName,
    gaEventProvider: () => _gtagEvent(
      event_category: gac.timingEvent,
      event_label: timedOperation,
      value: durationMicros,
      send_to: gaDevToolsPropertyId(),
      screenMetrics: screenMetrics,
    ),
  );
}

void select(
  String screenName,
  String selectedItem, {
  int value = 0,
  bool nonInteraction = false,
  ScreenAnalyticsMetrics Function()? screenMetricsProvider,
}) {
  _log.fine(
    'Event: select('
    'screenName:$screenName, '
    'selectedItem:$selectedItem, '
    'value:$value, '
    'nonInteraction:$nonInteraction)',
  );
  GTag.event(
    screenName,
    gaEventProvider: () => _gtagEvent(
      event_category: gac.selectEvent,
      event_label: selectedItem,
      value: value,
      non_interaction: nonInteraction,
      send_to: gaDevToolsPropertyId(),
      screenMetrics:
          screenMetricsProvider != null ? screenMetricsProvider() : null,
    ),
  );
}

String? _lastGaError;

void reportError(
  String errorMessage, {
  bool fatal = false,
  ScreenAnalyticsMetrics Function()? screenMetricsProvider,
}) {
  // Don't keep recording same last error.
  if (_lastGaError == errorMessage) return;
  _lastGaError = errorMessage;

  GTag.exception(
    gaExceptionProvider: () => _gtagException(
      errorMessage,
      fatal: fatal,
      screenMetrics:
          screenMetricsProvider != null ? screenMetricsProvider() : null,
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

set userAppType(String userAppType) {
  userAppType = userAppType;
}

String get userBuildType => _userBuildType;

set userBuildType(String userBuildType) {
  userBuildType = userBuildType;
}

String get userPlatformType => _userPlatformType;

set userPlatformType(String userPlatformType) {
  userPlatformType = userPlatformType;
}

String get devtoolsPlatformType => _devtoolsPlatformType;

set devtoolsPlatformType(String devtoolsPlatformType) {
  devtoolsPlatformType = devtoolsPlatformType;
}

String get devtoolsChrome => _devtoolsChrome;

set devtoolsChrome(String devtoolsChrome) {
  devtoolsChrome = devtoolsChrome;
}

String get ideLaunched => _ideLaunched;

set ideLaunched(String ideLaunched) {
  ideLaunched = ideLaunched;
}

String get flutterClientId => _flutterClientId;

set flutterClientId(String flutterClientId) {
  flutterClientId = flutterClientId;
}

bool _computingDimensions = false;
bool _analyticsComputed = false;

bool _computingUserApplicationDimensions = false;
bool _userApplicationDimensionsComputed = false;

// Computes the running application.
void _computeUserApplicationCustomGTagData() {
  if (_userApplicationDimensionsComputed) return;

  final connectedApp = serviceManager.connectedApp!;
  assert(connectedApp.isFlutterAppNow != null);
  assert(connectedApp.isDartWebAppNow != null);
  assert(connectedApp.isProfileBuildNow != null);

  const unknownOS = 'unknown';
  if (connectedApp.isFlutterAppNow!) {
    userPlatformType = serviceManager.vm?.operatingSystem ?? unknownOS;
  }
  if (connectedApp.isFlutterWebAppNow) {
    userAppType = appTypeFlutterWeb;
  } else if (connectedApp.isFlutterAppNow!) {
    userAppType = appTypeFlutter;
  } else if (connectedApp.isDartWebAppNow!) {
    userAppType = appTypeWeb;
  } else {
    userAppType = appTypeDartCLI;
  }

  userBuildType =
      connectedApp.isProfileBuildNow! ? buildTypeProfile : buildTypeDebug;

  _analyticsComputed = true;
}

@JS('getDevToolsPropertyID')
external String gaDevToolsPropertyId();

@JS('hookupListenerForGA')
external void jsHookupListenerForGA();

Future<bool> enableAnalytics() async {
  return await setAnalyticsEnabled(true);
}

Future<bool> disableAnalytics() async {
  return await setAnalyticsEnabled(false);
}

/// Computes the DevTools application. Fills in the devtoolsPlatformType and
/// devtoolsChrome.
void computeDevToolsCustomGTagsData() {
  // Platform
  final String platform = window.navigator.platform!;
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

Future<void> computeFlutterClientId() async {
  flutterClientId = await server.flutterGAClientID();
}

int _stillWaiting = 0;

void waitForDimensionsComputed(String screenName) {
  Timer(const Duration(milliseconds: 100), () {
    if (_analyticsComputed) {
      screen(screenName);
    } else {
      if (_stillWaiting++ < 50) {
        waitForDimensionsComputed(screenName);
      } else {
        _log.warning('Cancel waiting for dimensions.');
      }
    }
  });
}

Future<void> setupDimensions() async {
  if (!_analyticsComputed && !_computingDimensions) {
    _computingDimensions = true;
    computeDevToolsCustomGTagsData();
    computeDevToolsQueryParams();
    await computeFlutterClientId();
    _analyticsComputed = true;
  }
}

void setupUserApplicationDimensions() {
  if (serviceManager.connectedApp != null &&
      !_userApplicationDimensionsComputed &&
      !_computingUserApplicationDimensions) {
    _computingUserApplicationDimensions = true;
    _computeUserApplicationCustomGTagData();
    _userApplicationDimensionsComputed = true;
  }
}

Map<String, dynamic> generateSurveyQueryParameters() {
  const ideKey = 'IDE';
  const fromKey = 'From';
  const internalKey = 'Internal';

  final internalValue = (!isExternalBuild).toString();
  final fromPage = extractCurrentPageFromUrl(window.location.toString());

  return {
    ideKey: ideLaunched,
    fromKey: fromPage,
    internalKey: internalValue,
  };
}
