// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: non_constant_identifier_names

import 'dart:async';

import 'package:devtools_app_shared/ui.dart' as app_ui;
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:stack_trace/stack_trace.dart' as stack_trace;
import 'package:unified_analytics/unified_analytics.dart' as ua;
import 'package:web/web.dart';

import '../globals.dart' as globals;
import '../managers/dtd_manager_extensions.dart';
import '../primitives/query_parameters.dart';
import '../server/server.dart' as server;
import '../utils/utils.dart';
import 'analytics_common.dart';
import 'constants.dart' as gac;
import 'metrics.dart';

/// userApp values.
enum _UserAppType {
  flutter,
  web,
  flutterWeb,
  dartCLI;

  String get value {
    switch (this) {
      case _UserAppType.flutter:
        return 'flutter';
      case _UserAppType.web:
        return 'web';
      case _UserAppType.flutterWeb:
        return 'flutter_web';
      case _UserAppType.dartCLI:
        return 'dart_cli';
    }
  }
}

/// userBuild values.
enum _UserBuildType { debug, profile }

// Start with Android_n.n.n
const devToolsPlatformTypeAndroid = 'Android_';

/// devToolsChrome prefix identifiers.
enum _ChromePrefix {
  chrome,
  crios,
  cros;

  String get value {
    switch (this) {
      case _ChromePrefix.chrome:
        return 'Chrome/'; // starts with and ends with n.n.n
      case _ChromePrefix.crios:
        return 'Crios/'; // starts with and ends with n.n.n
      case _ChromePrefix.cros:
        return 'CrOS'; // Chrome OS
    }
  }
}

final _log = Logger('_analytics_web');

class DevToolsAnalyticsEvent {
  DevToolsAnalyticsEvent._({
    required this.screen,
    required this.eventCategory,
    required this.eventLabel,
    required this.value,
    required this.nonInteraction,
    // IMPORTANT! Only string and int values are supported. All other value
    // types will be ignored in GA4.
    this.userApp, // [_UserAppType]
    this.userBuild, // [_UserBuildType]
    this.userPlatform, // (android/ios/fuchsia/linux/mac/windows)
    this.devtoolsPlatform, // linux/android/mac/windows
    this.devtoolsChrome, // Chrome version #
    this.devtoolsVersion, // DevTools version #
    this.ideLaunched, // Devtools launched (CLI, VSCode, Android)
    this.flutterClientId, // Flutter tool client_id (~/.flutter).
    this.isExternalBuild, // External build or google3
    this.isEmbedded, // Whether devtools is embedded
    this.g3Username, // g3 username (null for external users)
    // IDE feature that launched Devtools
    // The following is a non-exhaustive list of possible values for this dimension:
    // "command" - VS Code command palette
    // "sidebarContent" - the content of the sidebar (e.g. the DevTools dropdown for a debug session)
    // "sidebarTitle" - the DevTools action in the sidebar title
    // "touchbar" - MacOS touchbar button
    // "launchConfiguration" - configured explicitly in launch configuration
    // "onDebugAutomatic" - configured to always run on debug session start
    // "onDebugPrompt" - user responded to prompt when running a debug session
    // "languageStatus" - launched from the language status popout
    this.ideLaunchedFeature,
    this.isWasm, // whether DevTools is running with WASM.
    // Performance screen metrics. See [PerformanceScreenMetrics].
    this.uiDurationMicros, // metric1
    this.rasterDurationMicros, // metric2
    this.shaderCompilationDurationMicros, // metric3
    // Profiler screen metrics. See [ProfilerScreenMetrics].
    this.cpuSampleCount, // metric4
    this.cpuStackDepth, // metric5
    // Performance screen metric. See [PerformanceScreenMetrics].
    this.traceEventCount, // metric6
    // Memory screen metric. See [MemoryScreenMetrics].
    this.heapDiffObjectsBefore, // metric7
    this.heapDiffObjectsAfter, // metric8
    this.heapObjectsTotal, // metric9
    // Inspector screen metrics. See [InspectorScreenMetrics].
    this.rootSetCount, // metric10
    this.rowCount, // metric11
    this.inspectorTreeControllerId, // metric12
    // Deep Link screen metrics. See [DeepLinkScreenMetrics].
    this.androidAppId, //metric13
    this.iosBundleId, //metric14
    // Inspector screen metrics. See [InspectorScreenMetrics].
    this.isV2Inspector, // metric15
  });

  factory DevToolsAnalyticsEvent._create({
    required String screen,
    required String eventCategory,
    required String eventLabel,
    bool nonInteraction = false,
    int value = 0,
    ScreenAnalyticsMetrics? screenMetrics,
  }) {
    return DevToolsAnalyticsEvent._(
      screen: screen,
      eventCategory: eventCategory,
      eventLabel: eventLabel,
      nonInteraction: nonInteraction,
      value: value,
      userApp: userAppType,
      userBuild: userBuildType,
      userPlatform: userPlatformType,
      devtoolsPlatform: _devtoolsPlatformType,
      devtoolsChrome: _devtoolsChrome,
      devtoolsVersion: devToolsVersion,
      ideLaunched: _ideLaunched,
      flutterClientId: _flutterClientId,
      isExternalBuild: globals.isExternalBuild.toString(),
      isEmbedded: app_ui.isEmbedded().toString(),
      g3Username: globals.devToolsEnvironmentParameters.username(),
      ideLaunchedFeature: _ideLaunchedFeature,
      isWasm: kIsWasm.toString(),
      // [PerformanceScreenMetrics]
      uiDurationMicros: screenMetrics is PerformanceScreenMetrics
          ? screenMetrics.uiDuration?.inMicroseconds
          : null,
      rasterDurationMicros: screenMetrics is PerformanceScreenMetrics
          ? screenMetrics.rasterDuration?.inMicroseconds
          : null,
      shaderCompilationDurationMicros: screenMetrics is PerformanceScreenMetrics
          ? screenMetrics.shaderCompilationDuration?.inMicroseconds
          : null,
      traceEventCount: screenMetrics is PerformanceScreenMetrics
          ? screenMetrics.traceEventCount
          : null,
      // [ProfilerScreenMetrics]
      cpuSampleCount: screenMetrics is ProfilerScreenMetrics
          ? screenMetrics.cpuSampleCount
          : null,
      cpuStackDepth: screenMetrics is ProfilerScreenMetrics
          ? screenMetrics.cpuStackDepth
          : null,
      // [MemoryScreenMetrics]
      heapDiffObjectsBefore: screenMetrics is MemoryScreenMetrics
          ? screenMetrics.heapDiffObjectsBefore
          : null,
      heapDiffObjectsAfter: screenMetrics is MemoryScreenMetrics
          ? screenMetrics.heapDiffObjectsAfter
          : null,
      heapObjectsTotal: screenMetrics is MemoryScreenMetrics
          ? screenMetrics.heapObjectsTotal
          : null,
      // [InspectorScreenMetrics]
      rootSetCount: screenMetrics is InspectorScreenMetrics
          ? screenMetrics.rootSetCount
          : null,
      rowCount: screenMetrics is InspectorScreenMetrics
          ? screenMetrics.rowCount
          : null,
      inspectorTreeControllerId: screenMetrics is InspectorScreenMetrics
          ? screenMetrics.inspectorTreeControllerId
          : null,
      // [DeepLinkScreenMetrics]
      androidAppId: screenMetrics is DeepLinkScreenMetrics
          ? screenMetrics.androidAppId
          : null,
      iosBundleId: screenMetrics is DeepLinkScreenMetrics
          ? screenMetrics.iosBundleId
          : null,
      // [InspectorScreenMetrics]
      // TODO(https://github.com/flutter/devtools/issues/9563): Remove this
      // dimension after dashboards have been updated to not include it. The
      // legacy inspector will be removed in Flutter 3.47 (Aug 2026), leaving
      // the V2 inspector the only inspector.
      isV2Inspector: screenMetrics is InspectorScreenMetrics
          ? true.toString()
          : null,
    );
  }

  String? screen;
  String? eventCategory;
  String? eventLabel;
  bool nonInteraction;
  int value;

  // Custom dimensions:
  String? userApp;
  String? userBuild;
  String? userPlatform;
  String? devtoolsPlatform;
  String? devtoolsChrome;
  String? devtoolsVersion;
  String? ideLaunched;
  String? flutterClientId;
  String? isExternalBuild;
  String? isEmbedded;
  String? g3Username;
  String? ideLaunchedFeature;
  String? isWasm;

  // Custom metrics:
  int? uiDurationMicros;
  int? rasterDurationMicros;
  int? shaderCompilationDurationMicros;
  int? cpuSampleCount;
  int? cpuStackDepth;
  int? traceEventCount;
  int? heapDiffObjectsBefore;
  int? heapDiffObjectsAfter;
  int? heapObjectsTotal;
  int? rootSetCount;
  int? rowCount;
  int? inspectorTreeControllerId;
  String? androidAppId;
  String? iosBundleId;
  String? isV2Inspector;
}

class DevToolsAnalyticsException {
  DevToolsAnalyticsException._({
    this.description,
    required this.fatal,

    // NOTE: Do not reorder any of these. Order here must match the order in the
    // Google Analytics console.
    // IMPORTANT! Only string and int values are supported. All other value
    // types will be ignored in GA4.
    this.userApp, // [_UserAppType]
    this.userBuild, // [_UserBuildType]
    this.userPlatform, // (android/ios/fuchsia/linux/mac/windows)
    this.devtoolsPlatform, // linux/android/mac/windows
    this.devtoolsChrome, // Chrome version #
    this.devtoolsVersion, // DevTools version #
    this.ideLaunched, // IDE launched DevTools
    this.flutterClientId, // Flutter tool clientId
    this.isExternalBuild, // External build or google3
    this.isEmbedded, // Whether devtools is embedded
    this.g3Username, // g3 username (null for external users)
    // IDE feature that launched Devtools
    // The following is a non-exhaustive list of possible values for this dimension:
    // "command" - VS Code command palette
    // "sidebarContent" - the content of the sidebar (e.g. the DevTools dropdown for a debug session)
    // "sidebarTitle" - the DevTools action in the sidebar title
    // "touchbar" - MacOS touchbar button
    // "launchConfiguration" - configured explicitly in launch configuration
    // "onDebugAutomatic" - configured to always run on debug session start
    // "onDebugPrompt" - user responded to prompt when running a debug session
    // "languageStatus" - launched from the language status popout
    this.ideLaunchedFeature,
    this.isWasm, // whether DevTools is running with WASM.
    // Performance screen metrics. See [PerformanceScreenMetrics].
    this.uiDurationMicros, // metric1
    this.rasterDurationMicros, // metric2
    this.shaderCompilationDurationMicros, // metric3
    // Profiler screen metrics. See [ProfilerScreenMetrics].
    this.cpuSampleCount, // metric4
    this.cpuStackDepth, // metric5
    // Performance screen metric. See [PerformanceScreenMetrics].
    this.traceEventCount, // metric6
    // Memory screen metric. See [MemoryScreenMetrics].
    this.heapDiffObjectsBefore, // metric7
    this.heapDiffObjectsAfter, // metric8
    this.heapObjectsTotal, // metric9
    // Inspector screen metrics. See [InspectorScreenMetrics].
    this.rootSetCount, // metric10
    this.rowCount, // metric11
    this.inspectorTreeControllerId, // metric12
    // Deep Link screen metrics. See [DeepLinkScreenMetrics].
    this.androidAppId, //metric13
    this.iosBundleId, //metric14
    // Inspector screen metrics. See [InspectorScreenMetrics].
    this.isV2Inspector, // metric15
  });

  factory DevToolsAnalyticsException._create(
    String errorMessage, {
    bool fatal = false,
    ScreenAnalyticsMetrics? screenMetrics,
  }) {
    return DevToolsAnalyticsException._(
      description: errorMessage,
      fatal: fatal,
      userApp: userAppType,
      userBuild: userBuildType,
      userPlatform: userPlatformType,
      devtoolsPlatform: _devtoolsPlatformType,
      devtoolsChrome: _devtoolsChrome,
      devtoolsVersion: devToolsVersion,
      ideLaunched: _ideLaunched,
      flutterClientId: _flutterClientId,
      isExternalBuild: globals.isExternalBuild.toString(),
      isEmbedded: app_ui.isEmbedded().toString(),
      g3Username: globals.devToolsEnvironmentParameters.username(),
      ideLaunchedFeature: _ideLaunchedFeature,
      isWasm: kIsWasm.toString(),
      // [PerformanceScreenMetrics]
      uiDurationMicros: screenMetrics is PerformanceScreenMetrics
          ? screenMetrics.uiDuration?.inMicroseconds
          : null,
      rasterDurationMicros: screenMetrics is PerformanceScreenMetrics
          ? screenMetrics.rasterDuration?.inMicroseconds
          : null,
      traceEventCount: screenMetrics is PerformanceScreenMetrics
          ? screenMetrics.traceEventCount
          : null,
      shaderCompilationDurationMicros: screenMetrics is PerformanceScreenMetrics
          ? screenMetrics.shaderCompilationDuration?.inMicroseconds
          : null,
      // [ProfilerScreenMetrics]
      cpuSampleCount: screenMetrics is ProfilerScreenMetrics
          ? screenMetrics.cpuSampleCount
          : null,
      cpuStackDepth: screenMetrics is ProfilerScreenMetrics
          ? screenMetrics.cpuStackDepth
          : null,
      // [MemoryScreenMetrics]
      heapDiffObjectsBefore: screenMetrics is MemoryScreenMetrics
          ? screenMetrics.heapDiffObjectsBefore
          : null,
      heapDiffObjectsAfter: screenMetrics is MemoryScreenMetrics
          ? screenMetrics.heapDiffObjectsAfter
          : null,
      heapObjectsTotal: screenMetrics is MemoryScreenMetrics
          ? screenMetrics.heapObjectsTotal
          : null,
      // [InspectorScreenMetrics]
      rootSetCount: screenMetrics is InspectorScreenMetrics
          ? screenMetrics.rootSetCount
          : null,
      rowCount: screenMetrics is InspectorScreenMetrics
          ? screenMetrics.rowCount
          : null,
      inspectorTreeControllerId: screenMetrics is InspectorScreenMetrics
          ? screenMetrics.inspectorTreeControllerId
          : null,
      // [DeepLinkScreenMetrics]
      androidAppId: screenMetrics is DeepLinkScreenMetrics
          ? screenMetrics.androidAppId
          : null,
      iosBundleId: screenMetrics is DeepLinkScreenMetrics
          ? screenMetrics.iosBundleId
          : null,
      // [InspectorScreenMetrics]
      isV2Inspector: screenMetrics is InspectorScreenMetrics
          ? true.toString()
          : null,
    );
  }

  String? description;
  bool fatal;

  // Custom dimensions:
  String? userApp;
  String? userBuild;
  String? userPlatform;
  String? devtoolsPlatform;
  String? devtoolsChrome;
  String? devtoolsVersion;
  String? ideLaunched;
  String? flutterClientId;
  String? isExternalBuild;
  String? isEmbedded;
  String? g3Username;
  String? ideLaunchedFeature;
  String? isWasm;

  // Custom metrics:
  int? uiDurationMicros;
  int? rasterDurationMicros;
  int? shaderCompilationDurationMicros;
  int? cpuSampleCount;
  int? cpuStackDepth;
  int? traceEventCount;
  int? heapDiffObjectsBefore;
  int? heapDiffObjectsAfter;
  int? heapObjectsTotal;
  int? rootSetCount;
  int? rowCount;
  int? inspectorTreeControllerId;
  String? androidAppId;
  String? iosBundleId;
  String? isV2Inspector;
}

void screen(String screenName, [int value = 0]) {
  _log.fine('Event: Screen(screenName:$screenName, value:$value)');
  final gtagEvent = DevToolsAnalyticsEvent._create(
    screen: screenName,
    eventCategory: gac.screenViewEvent,
    eventLabel: gac.init,
    value: value,
  );
  _sendEvent(gtagEvent);
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
  final operationKey = _operationKey(screenName, timedOperation);
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
  final operationKey = _operationKey(screenName, timedOperation);
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
    screenMetrics: screenMetricsProvider != null
        ? screenMetricsProvider()
        : null,
  );
}

void cancelTimingOperation(String screenName, String timedOperation) {
  final operationKey = _operationKey(screenName, timedOperation);
  final operation = _timedOperationsInProgress.remove(operationKey);
  assert(
    operation != null,
    'The operation $screenName.$timedOperation cannot be cancelled because it '
    'does not exist.',
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
    screenMetrics: screenMetricsProvider != null
        ? screenMetricsProvider()
        : null,
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
    screenMetrics: screenMetricsProvider != null
        ? screenMetricsProvider()
        : null,
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
  final gtagEvent = DevToolsAnalyticsEvent._create(
    screen: screenName,
    eventCategory: gac.timingEvent,
    eventLabel: timedOperation,
    value: durationMicros,
    screenMetrics: screenMetrics,
  );
  _sendEvent(gtagEvent);
}

/// Sends an analytics event to signal that something in DevTools was selected.
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
  final gtagEvent = DevToolsAnalyticsEvent._create(
    screen: screenName,
    eventCategory: gac.selectEvent,
    eventLabel: selectedItem,
    value: value,
    nonInteraction: nonInteraction,
    screenMetrics: screenMetricsProvider != null
        ? screenMetricsProvider()
        : null,
  );
  _sendEvent(gtagEvent);
}

/// Sends an analytics event to signal that something in DevTools was viewed.
///
/// Impression events should not signal user interaction like [select].
void impression(
  String screenName,
  String item, {
  ScreenAnalyticsMetrics Function()? screenMetricsProvider,
}) {
  _log.fine(
    'Event: impression('
    'screenName:$screenName, '
    'item:$item)',
  );
  final gtagEvent = DevToolsAnalyticsEvent._create(
    screen: screenName,
    eventCategory: gac.impressionEvent,
    eventLabel: item,
    nonInteraction: true,
    screenMetrics: screenMetricsProvider != null
        ? screenMetricsProvider()
        : null,
  );
  _sendEvent(gtagEvent);
}

String? _lastGaError;

/// Reports an error to analytics.
///
/// [errorMessage] is the description of the error.
/// [stackTrace] is the stack trace.
void reportError(
  String errorMessage, {
  stack_trace.Trace? stackTrace,
  bool fatal = false,
}) {
  // Don't keep recording same last error.
  if (_lastGaError == errorMessage) return;
  _lastGaError = errorMessage;

  final uaEvent = _uaEventFromDevToolsException(
    DevToolsAnalyticsException._create(errorMessage, fatal: fatal),
    stackTrace: stackTrace,
  );
  unawaited(globals.dtdManager.sendAnalyticsEvent(uaEvent));
}

////////////////////////////////////////////////////////////////////////////////
// Utilities to collect all platform and DevTools state for Analytics.
////////////////////////////////////////////////////////////////////////////////

String _userAppType = '';
String _userBuildType = '';
String _userPlatformType = '';

/// MacIntel/Linux/Windows/Android_n
String _devtoolsPlatformType = '';

/// Chrome/n.n.n  or Crios/n.n.n
String _devtoolsChrome = '';

/// IDE launched DevTools (VSCode, CLI, ...)
String _ideLaunched = '';

/// The IDE feature that launched DevTools.
///
/// Defaults to [_ideLaunchedCLI] if DevTools was not launched from the IDE.
String _ideLaunchedFeature = '';

/// Flutter tool clientId.
String _flutterClientId = '';

String get userAppType => _userAppType;

set userAppType(String newUserAppType) {
  _userAppType = newUserAppType;
}

String get userBuildType => _userBuildType;

set userBuildType(String newUserBuildType) {
  _userBuildType = newUserBuildType;
}

String get userPlatformType => _userPlatformType;

set userPlatformType(String newUserPlatformType) {
  _userPlatformType = newUserPlatformType;
}

String get ideLaunched => _ideLaunched;

String get ideLaunchedFeature => _ideLaunchedFeature;

set ideLaunchedFeature(String newIdeLaunchedFeature) {
  _ideLaunchedFeature = newIdeLaunchedFeature;
}

Completer<void>? _computingDimensionsCompleter;

/// Computes the running application.
void _computeUserApplicationCustomGTagData() {
  final connectedApp = globals.serviceConnection.serviceManager.connectedApp!;
  assert(connectedApp.isFlutterAppNow != null);
  assert(connectedApp.isDartWebAppNow != null);
  assert(connectedApp.isProfileBuildNow != null);

  const unknownOS = 'unknown';
  if (connectedApp.isFlutterAppNow!) {
    userPlatformType =
        globals.serviceConnection.serviceManager.vm?.operatingSystem ??
        unknownOS;
  }
  if (connectedApp.isFlutterWebAppNow) {
    userAppType = _UserAppType.flutterWeb.value;
  } else if (connectedApp.isFlutterAppNow!) {
    userAppType = _UserAppType.flutter.value;
  } else if (connectedApp.isDartWebAppNow!) {
    userAppType = _UserAppType.web.value;
  } else {
    userAppType = _UserAppType.dartCLI.value;
  }

  userBuildType = connectedApp.isProfileBuildNow!
      ? _UserBuildType.profile.name
      : _UserBuildType.debug.name;
}

/// Computes the DevTools application data.
///
/// Fills in the [_devtoolsPlatformType] and [_devtoolsChrome].
void computeDevToolsCustomData() {
  _devtoolsPlatformType = window.navigator.platform.replaceAll(' ', '_');
  final appVersion = window.navigator.appVersion;
  final splits = appVersion.split(' ');
  final len = splits.length;
  for (int index = 0; index < len; index++) {
    final value = splits[index];
    // Chrome or Chrome iOS
    if (value.startsWith(_ChromePrefix.chrome.value) ||
        value.startsWith(_ChromePrefix.crios.value)) {
      _devtoolsChrome = value;
    } else if (value.startsWith('Android') && index + 1 < splits.length) {
      // appVersion for Android is 'Android n.n.n'
      _devtoolsPlatformType =
          '$devToolsPlatformTypeAndroid${splits[index + 1]}';
    } else if (value == _ChromePrefix.cros.value) {
      // Chrome OS will return a platform e.g., CrOS_Linux_x86_64
      _devtoolsPlatformType =
          '${_ChromePrefix.cros.value}_$_devtoolsPlatformType';
    }
  }
}

const _ideLaunchedCLI = 'CLI';

/// Look at the query parameters '&ide=' and set values.
void computeDevToolsQueryParams() {
  // Default is Command Line launch.
  _ideLaunched = _ideLaunchedCLI;

  final queryParams = DevToolsQueryParams.load();
  final ide = queryParams.ide;
  if (ide != null) {
    _ideLaunched = ide;
  }

  final ideFeature = queryParams.ideFeature;
  if (ideFeature != null) {
    ideLaunchedFeature = ideFeature;
  }
}

Future<void> computeFlutterClientId() async {
  _flutterClientId = await server.flutterGAClientID();
}

Future<void> setupDimensions() async {
  if (_computingDimensionsCompleter != null) {
    return _computingDimensionsCompleter!.future;
  }

  _computingDimensionsCompleter = Completer<void>();
  try {
    computeDevToolsCustomData();
    computeDevToolsQueryParams();
    await computeFlutterClientId();
  } catch (e, st) {
    _log.warning('Failed to compute dimensions', e, st);
  } finally {
    _computingDimensionsCompleter!.complete();
  }
}

void setupUserApplicationDimensions() {
  if (globals.serviceConnection.serviceManager.connectedApp == null) {
    return;
  }

  try {
    _computeUserApplicationCustomGTagData();
  } catch (e, st) {
    _log.warning('Failed to compute user application dimensions', e, st);
  }
}

Map<String, Object?> generateSurveyQueryParameters() {
  const ideKey = 'IDE';
  const versionKey = 'Version';
  const internalKey = 'Internal';
  return {
    ideKey: _ideLaunched,
    versionKey: devToolsVersion,
    internalKey: (!globals.isExternalBuild).toString(),
  };
}

void _sendEvent(DevToolsAnalyticsEvent event) {
  final uaEvent = _uaEventFromDevToolsEvent(event);
  unawaited(globals.dtdManager.sendAnalyticsEvent(uaEvent));
}

ua.Event _uaEventFromDevToolsEvent(DevToolsAnalyticsEvent event) {
  // Any dimensions or metrics that have a null value will be removed from
  // the event data in the [ua.Event.devtoolsEvent] constructor.
  return ua.Event.devtoolsEvent(
    screen: event.screen!,
    eventCategory: event.eventCategory!,
    label: event.eventLabel!,
    value: event.value,
    userInitiatedInteraction: !event.nonInteraction,
    userApp: event.userApp,
    userBuild: event.userBuild,
    userPlatform: event.userPlatform,
    devtoolsPlatform: event.devtoolsPlatform,
    devtoolsChrome: event.devtoolsChrome,
    devtoolsVersion: event.devtoolsVersion,
    ideLaunched: event.ideLaunched,
    ideLaunchedFeature: event.ideLaunchedFeature,
    isExternalBuild: event.isExternalBuild,
    isEmbedded: event.isEmbedded,
    isWasm: event.isWasm,
    g3Username: event.g3Username,
    // Only 25 entries are permitted for GA4 event parameters, but since not
    // all of the below metrics will be non-null at the same time, it is okay to
    // include all the metrics here. The [ua.Event.devtoolsEvent] constructor
    // will remove any entries with a null value from the sent event parameters.
    additionalMetrics: _DevToolsEventMetrics(
      uiDurationMicros: event.uiDurationMicros,
      rasterDurationMicros: event.rasterDurationMicros,
      shaderCompilationDurationMicros: event.shaderCompilationDurationMicros,
      traceEventCount: event.traceEventCount,
      cpuSampleCount: event.cpuSampleCount,
      cpuStackDepth: event.cpuStackDepth,
      heapDiffObjectsBefore: event.heapDiffObjectsBefore,
      heapDiffObjectsAfter: event.heapDiffObjectsAfter,
      heapObjectsTotal: event.heapObjectsTotal,
      rootSetCount: event.rootSetCount,
      rowCount: event.rowCount,
      inspectorTreeControllerId: event.inspectorTreeControllerId,
      isV2Inspector: event.isV2Inspector,
      androidAppId: event.androidAppId,
      iosBundleId: event.iosBundleId,
    ),
  );
}

ua.Event _uaEventFromDevToolsException(
  DevToolsAnalyticsException exception, {
  stack_trace.Trace? stackTrace,
}) {
  final stackTraceAsMap = createStackTraceForAnalytics(stackTrace);

  // Any data entries that have a null value will be removed from the event data
  // in the [ua.Event.exception] constructor.
  return ua.Event.exception(
    exception: exception.description ?? 'unknown exception',
    data: {
      'fatal': exception.fatal,
      ...stackTraceAsMap,
      'userApp': exception.userApp,
      'userBuild': exception.userBuild,
      'userPlatform': exception.userPlatform,
      'devtoolsPlatform': exception.devtoolsPlatform,
      'devtoolsChrome': exception.devtoolsChrome,
      'devtoolsVersion': exception.devtoolsVersion,
      'ideLaunched': exception.ideLaunched,
      'ideLaunchedFeature': exception.ideLaunchedFeature,
      'isExternalBuild': exception.isExternalBuild,
      'isEmbedded': exception.isEmbedded,
      'isWasm': exception.isWasm,
      'g3Username': exception.g3Username,
      // Do not include metrics in exceptions because GA4 event parameter are
      // limited to 25 entries, and we need to reserve entries for the stack
      // trace chunks.
    },
  );
}

final class _DevToolsEventMetrics extends ua.CustomMetrics {
  _DevToolsEventMetrics({
    required this.rasterDurationMicros,
    required this.shaderCompilationDurationMicros,
    required this.traceEventCount,
    required this.cpuSampleCount,
    required this.cpuStackDepth,
    required this.heapDiffObjectsBefore,
    required this.heapDiffObjectsAfter,
    required this.heapObjectsTotal,
    required this.rootSetCount,
    required this.rowCount,
    required this.inspectorTreeControllerId,
    required this.isV2Inspector,
    required this.androidAppId,
    required this.iosBundleId,
    required this.uiDurationMicros,
  });

  // [PerformanceScreenMetrics]
  final int? uiDurationMicros;
  final int? rasterDurationMicros;
  final int? shaderCompilationDurationMicros;
  final int? traceEventCount;

  // [ProfilerScreenMetrics]
  final int? cpuSampleCount;
  final int? cpuStackDepth;

  // [MemoryScreenMetrics]
  final int? heapDiffObjectsBefore;
  final int? heapDiffObjectsAfter;
  final int? heapObjectsTotal;

  // [InspectorScreenMetrics]
  final int? rootSetCount;
  final int? rowCount;
  final int? inspectorTreeControllerId;
  final String? isV2Inspector;

  // [DeepLinkScreenMetrics]
  final String? androidAppId;
  final String? iosBundleId;

  @override
  Map<String, Object> toMap() => (<String, Object?>{
    'uiDurationMicros': uiDurationMicros,
    'rasterDurationMicros': rasterDurationMicros,
    'shaderCompilationDurationMicros': shaderCompilationDurationMicros,
    'traceEventCount': traceEventCount,
    'cpuSampleCount': cpuSampleCount,
    'cpuStackDepth': cpuStackDepth,
    'heapDiffObjectsBefore': heapDiffObjectsBefore,
    'heapDiffObjectsAfter': heapDiffObjectsAfter,
    'heapObjectsTotal': heapObjectsTotal,
    'rootSetCount': rootSetCount,
    'rowCount': rowCount,
    'inspectorTreeControllerId': inspectorTreeControllerId,
    'isV2Inspector': isV2Inspector,
    'androidAppId': androidAppId,
    'iosBundleId': iosBundleId,
  }..removeWhere((key, value) => value == null)).cast<String, Object>();
}
