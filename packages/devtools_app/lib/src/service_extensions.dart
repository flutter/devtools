// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library service_extensions;

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'analytics/constants.dart' as analytics_constants;
import 'ui/icons.dart';

// Each service extension needs to be added to [_extensionDescriptions].
class ToggleableServiceExtensionDescription<T>
    extends ServiceExtensionDescription {
  ToggleableServiceExtensionDescription._({
    Widget disabledIcon,
    Widget enabledIcon,
    @required String extension,
    @required String description,
    @required T enabledValue,
    @required T disabledValue,
    @required String enabledTooltip,
    @required String disabledTooltip,
    @required String gaScreenName,
    @required String gaItem,
    bool shouldCallOnAllIsolates = false,
  }) : super(
          extension: extension,
          description: description,
          disabledIcon: disabledIcon,
          enabledIcon: enabledIcon,
          values: [enabledValue, disabledValue],
          tooltips: [enabledTooltip, disabledTooltip],
          gaScreenName: gaScreenName,
          gaItem: gaItem,
          shouldCallOnAllIsolates: shouldCallOnAllIsolates,
        );

  static const enabledValueIndex = 0;

  static const disabledValueIndex = 1;

  T get enabledValue => values[enabledValueIndex];

  T get disabledValue => values[disabledValueIndex];

  String get enabledTooltip => tooltips[enabledValueIndex];

  String get disabledTooltip => tooltips[disabledValueIndex];
}

class ServiceExtensionDescription<T> {
  ServiceExtensionDescription({
    this.disabledIcon,
    this.enabledIcon,
    List<String> displayValues,
    @required this.extension,
    @required this.description,
    @required this.values,
    @required this.tooltips,
    @required this.gaScreenName,
    @required this.gaItem,
    this.shouldCallOnAllIsolates = false,
  }) : displayValues =
            displayValues ?? values.map((v) => v.toString()).toList();

  final String extension;

  final String description;

  final Widget disabledIcon;

  final Widget enabledIcon;

  final List<T> values;

  final List<String> displayValues;

  final List<String> tooltips;

  final String gaScreenName; // Analytics screen (screen name where item lives).

  final String gaItem; // Analytics item name (toggleable item's name).

  final bool shouldCallOnAllIsolates;
}

final debugAllowBanner = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.debugAllowBanner',
  description: 'Debug Banner',
  disabledIcon: const AssetImageIcon(url: 'icons/debug_banner@2x.png'),
  enabledIcon: const AssetImageIcon(url: 'icons/debug_banner@2x.png'),
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Hide Debug Banner',
  disabledTooltip: 'Show Debug Banner',
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.debugBanner,
);

final invertOversizedImages = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.invertOversizedImages',
  description: 'Invert Oversized Images',
  disabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/images-dgrey.png',
    darkModeAsset: 'icons/images-lgrey.png',
  ),
  enabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/images-white.png',
    darkModeAsset: 'icons/images-dgrey.png',
  ),
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Disable Invert Oversized Images',
  disabledTooltip: 'Enable Invert Oversized Images',
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.debugBanner,
);

final debugPaint = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.debugPaint',
  description: 'Show Guidelines',
  disabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/guidelines-dgrey.png',
    darkModeAsset: 'icons/guidelines-lgrey.png',
  ),
  enabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/guidelines-white.png',
    darkModeAsset: 'icons/guidelines-dgrey.png',
  ),
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Hide Debug Paint',
  disabledTooltip: 'Show Debug Paint',
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.debugPaint,
);

final debugPaintBaselines = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.debugPaintBaselinesEnabled',
  description: 'Show Baselines',
  disabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/baselines-dgrey.png',
    darkModeAsset: 'icons/baselines-lgrey.png',
  ),
  enabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/baselines-white.png',
    darkModeAsset: 'icons/baselines-dgrey.png',
  ),
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Hide Paint Baselines',
  disabledTooltip: 'Show Paint Baselines',
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.paintBaseline,
);

final performanceOverlay = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.showPerformanceOverlay',
  description: 'Performance Overlay',
  disabledIcon:
      const AssetImageIcon(url: 'icons/general/performance_overlay@2x.png'),
  enabledIcon:
      const AssetImageIcon(url: 'icons/general/performance_overlay@2x.png'),
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Hide Performance Overlay',
  disabledTooltip: 'Show Performance Overlay',
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.performanceOverlay,
);

final profileWidgetBuilds = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.profileWidgetBuilds',
  description: 'Track Widget Builds',
  disabledIcon: const AssetImageIcon(url: 'icons/widget_tree@2x.png'),
  enabledIcon: const AssetImageIcon(url: 'icons/widget_tree@2x.png'),
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Disable tracking widget builds',
  disabledTooltip: 'Enable tracking widget builds',
  gaScreenName: analytics_constants.performance,
  gaItem: analytics_constants.trackRebuilds,
);

final repaintRainbow = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.repaintRainbow',
  description: 'Highlight Repaints',
  disabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/repaints-dgrey.png',
    darkModeAsset: 'icons/repaints-lgrey.png',
  ),
  enabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/repaints-white.png',
    darkModeAsset: 'icons/repaints-dgrey.png',
  ),
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Hide Repaint Rainbow',
  disabledTooltip: 'Show Repaint Rainbow',
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.repaintRainbow,
);

final slowAnimations = ToggleableServiceExtensionDescription<num>._(
  extension: 'ext.flutter.timeDilation',
  description: 'Slow Animations',
  disabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/slow-dgrey.png',
    darkModeAsset: 'icons/slow-lgrey.png',
  ),
  enabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/slow-white.png',
    darkModeAsset: 'icons/slow-dgrey.png',
  ),
  enabledValue: 5.0,
  disabledValue: 1.0,
  enabledTooltip: 'Disable Slow Animations',
  disabledTooltip: 'Enable Slow Animations',
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.slowAnimation,
);

final togglePlatformMode = ServiceExtensionDescription<String>(
  extension: 'ext.flutter.platformOverride',
  description: 'Override target platform',
  disabledIcon: const AssetImageIcon(url: 'icons/phone@2x.png'),
  enabledIcon: const AssetImageIcon(url: 'icons/phone@2x.png'),
  values: ['iOS', 'android', 'fuchsia', 'macOS', 'linux'],
  displayValues: [
    'Platform: iOS',
    'Platform: Android',
    'Platform: Fuchsia',
    'Platform: MacOS',
    'Platform: Linux'
  ],
  tooltips: ['Override Target Platform'],
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.togglePlatform,
);

final httpEnableTimelineLogging = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.dart.io.httpEnableTimelineLogging',
  description: 'Whether HTTP timeline logging is enabled',
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'HTTP timeline logging enabled',
  disabledTooltip: 'HTTP timeline logging disabled',
  gaScreenName: null,
  gaItem: null,
  shouldCallOnAllIsolates: true,
);

final socketProfiling = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.dart.io.socketProfilingEnabled',
  description: 'Whether socket profiling is enabled',
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Socket profiling enabled',
  disabledTooltip: 'Socket profiling disabled',
  gaScreenName: null,
  gaItem: null,
  shouldCallOnAllIsolates: true,
);

// Legacy extension to show the inspector and enable inspector select mode.
final toggleOnDeviceWidgetInspector =
    ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.inspector.show',
  // Technically this enables the on-device widget inspector but for older
  // versions of package:flutter it makes sense to describe this extension as
  // toggling widget select mode as it is the only way to toggle that mode.
  description: 'Select Widget Mode',
  disabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/widget-select-dgrey.png',
    darkModeAsset: 'icons/widget-select-lgrey.png',
  ),
  enabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/widget-select-white.png',
    darkModeAsset: 'icons/widget-select-dgrey.png',
  ),
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Disable select widget mode',
  disabledTooltip: 'Enable select widget mode',
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.showOnDeviceInspector,
);

/// Toggle whether interacting with the device selects widgets or triggers
/// normal interactions.
final toggleSelectWidgetMode = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.inspector.selectMode',
  description: 'Select widget mode',
  disabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/widget-select-dgrey.png',
    darkModeAsset: 'icons/widget-select-lgrey.png',
  ),
  enabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/widget-select-white.png',
    darkModeAsset: 'icons/widget-select-dgrey.png',
  ),
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Exit select widget mode',
  disabledTooltip: 'Enter select widget mode',
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.selectWidgetMode,
);

/// Toggle whether the inspector on-device overlay is enabled.
///
/// When available, the inspector overlay can be enabled at any time as it will
/// not interfere with user interaction with the app unless inspector select
/// mode is triggered.
final enableOnDeviceInspector = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.inspector.enable',
  description: 'Enable on-device inspector',
  disabledIcon: const AssetImageIcon(url: 'icons/general/locate@2x.png'),
  enabledIcon: const AssetImageIcon(url: 'icons/general/locate@2x.png'),
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Exit on-device inspector',
  disabledTooltip: 'Enter on-device inspector',
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.enableOnDeviceInspector,
);

final structuredErrors = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.inspector.structuredErrors',
  description: 'Show structured errors',
  disabledIcon: const AssetImageIcon(url: 'icons/perf/RedExcl@2x.png'),
  enabledIcon: const AssetImageIcon(url: 'icons/perf/RedExcl@2x.png'),
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Disable structured errors for Flutter framework issues',
  disabledTooltip: 'Show structured errors for Flutter framework issues',
  gaScreenName: analytics_constants.logging,
  gaItem: analytics_constants.structuredErrors,
);

// This extension should never be displayed as a button so does not need a
// ServiceExtensionDescription object.
const String didSendFirstFrameEvent = 'ext.flutter.didSendFirstFrameEvent';

final List<ServiceExtensionDescription> _extensionDescriptions = [
  debugPaint,
  debugPaintBaselines,
  repaintRainbow,
  performanceOverlay,
  debugAllowBanner,
  profileWidgetBuilds,
  toggleOnDeviceWidgetInspector,
  toggleSelectWidgetMode,
  enableOnDeviceInspector,
  togglePlatformMode,
  slowAnimations,
  structuredErrors,
  httpEnableTimelineLogging,
  socketProfiling,
  invertOversizedImages,
];

final Map<String, ServiceExtensionDescription> serviceExtensionsAllowlist =
    Map.fromIterable(
  _extensionDescriptions,
  key: (extension) => extension.extension,
  value: (extension) => extension,
);

/// Service extensions that are not safe to call unless a frame has already
/// been rendered.
///
/// Flutter can sometimes crash if these extensions are called before the first
/// frame is done rendering. We are intentionally conservative about which
/// extensions are safe to run before the first frame as there is little harm
/// in setting these extensions after one frame has rendered without the
/// extension set.
final Set<String> _unsafeBeforeFirstFrameFlutterExtensions =
    <ServiceExtensionDescription>[
  debugPaint,
  debugPaintBaselines,
  repaintRainbow,
  performanceOverlay,
  debugAllowBanner,
  toggleOnDeviceWidgetInspector,
  toggleSelectWidgetMode,
  enableOnDeviceInspector,
  togglePlatformMode,
  slowAnimations,
].map((extension) => extension.extension).toSet();

bool isUnsafeBeforeFirstFlutterFrame(String extensionName) {
  return _unsafeBeforeFirstFrameFlutterExtensions.contains(extensionName);
}

bool isFlutterExtension(String extensionName) {
  return extensionName.startsWith('ext.flutter.');
}

bool isDartIoExtension(String extensionName) {
  return extensionName.startsWith('ext.dart.io.');
}
