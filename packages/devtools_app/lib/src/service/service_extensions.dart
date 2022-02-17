// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

library service_extensions;

import 'package:flutter/material.dart';

import '../analytics/constants.dart' as analytics_constants;
import '../shared/theme.dart';
import '../ui/icons.dart';

// Each service extension needs to be added to [_extensionDescriptions].
class ToggleableServiceExtensionDescription<T>
    extends ServiceExtensionDescription {
  ToggleableServiceExtensionDescription._({
    required Widget enabledIcon,
    Widget? disabledIcon,
    required String extension,
    required String title,
    required T enabledValue,
    required T disabledValue,
    required String? gaScreenName,
    required String? gaItem,
    required String tooltip,
    String? description,
    String? tooltipUrl,
    bool shouldCallOnAllIsolates = false,
    this.inverted = false,
  }) : super(
          extension: extension,
          title: title,
          enabledIcon: enabledIcon,
          disabledIcon: disabledIcon ?? enabledIcon,
          values: [enabledValue, disabledValue],
          gaScreenName: gaScreenName,
          gaItem: gaItem,
          shouldCallOnAllIsolates: shouldCallOnAllIsolates,
          tooltip: tooltip,
          description: description ?? title,
          tooltipUrl: tooltipUrl,
        );

  static const enabledValueIndex = 0;

  static const disabledValueIndex = 1;

  T get enabledValue => values[enabledValueIndex];

  T get disabledValue => values[disabledValueIndex];

  /// Whether this service extension will be inverted where it is exposed in
  /// DevTools.
  ///
  /// For example, when [inverted] is true, a service extension may have a value
  /// of 'false' in the framework, but will have a perceived value of 'true' in
  /// DevTools, where the language describing the service extension toggle will
  /// also be inverted.
  final bool inverted;
}

class ServiceExtensionDescription<T> {
  ServiceExtensionDescription({
    required this.enabledIcon,
    disabledIcon,
    List<String>? displayValues,
    required this.extension,
    required this.title,
    required this.values,
    required this.gaScreenName,
    required this.gaItem,
    required this.tooltip,
    this.description,
    this.tooltipUrl,
    this.shouldCallOnAllIsolates = false,
  })  : displayValues =
            displayValues ?? values.map((v) => v.toString()).toList(),
        disabledIcon = disabledIcon ?? enabledIcon;

  final String extension;

  final String title;

  final Widget enabledIcon;

  final Widget disabledIcon;

  final List<T> values;

  final List<String> displayValues;

  /// Analytics screen (screen name where item lives).
  final String? gaScreenName;

  /// Analytics item name (toggleable item's name).
  final String? gaItem;

  String get gaItemTooltipLink => '${gaItem}TooltipLink';

  final bool shouldCallOnAllIsolates;

  final String tooltip;

  final String? description;

  final String? tooltipUrl;
}

final debugAllowBanner = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.debugAllowBanner',
  title: 'Debug Banner',
  enabledIcon: const AssetImageIcon(asset: 'icons/debug_banner@2x.png'),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.debugBanner,
  tooltip: 'Toggle Debug Banner',
);

final invertOversizedImages = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.invertOversizedImages',
  title: 'Highlight Oversized Images',
  enabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/images-white.png',
    darkModeAsset: 'icons/images-dgrey.png',
  ),
  disabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/images-dgrey.png',
    darkModeAsset: 'icons/images-lgrey.png',
  ),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.debugBanner,
  tooltip:
      'Highlight images that are using too much memory by inverting colors and flipping them.',
  tooltipUrl:
      'https://flutter.dev/docs/development/tools/devtools/inspector#highlight-oversized-images',
);

final debugPaint = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.debugPaint',
  title: 'Show Guidelines',
  enabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/guidelines-white.png',
    darkModeAsset: 'icons/guidelines-dgrey.png',
  ),
  disabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/guidelines-dgrey.png',
    darkModeAsset: 'icons/guidelines-lgrey.png',
  ),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.debugPaint,
  tooltip: 'Overlay guidelines to assist with fixing layout issues.',
  tooltipUrl:
      'https://flutter.dev/docs/development/tools/devtools/inspector#show-guidelines',
);

final debugPaintBaselines = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.debugPaintBaselinesEnabled',
  title: 'Show Baselines',
  enabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/baselines-white.png',
    darkModeAsset: 'icons/baselines-dgrey.png',
  ),
  disabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/baselines-dgrey.png',
    darkModeAsset: 'icons/baselines-lgrey.png',
  ),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.paintBaseline,
  tooltip:
      'Show baselines, which are used to position text. Can be useful for checking if text is aligned.',
  tooltipUrl:
      'https://flutter.dev/docs/development/tools/devtools/inspector#show-baselines',
);

final performanceOverlay = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.showPerformanceOverlay',
  title: 'Performance Overlay',
  enabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/performance-white.png',
    darkModeAsset: 'icons/performance-dgrey.png',
  ),
  disabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/performance-dgrey.png',
    darkModeAsset: 'icons/performance-lgrey.png',
  ),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.performance,
  gaItem: analytics_constants.performanceOverlay,
  tooltip: 'Overlay a performance chart on your app.',
  tooltipUrl:
      'https://flutter.dev/docs/perf/rendering/ui-performance#the-performance-overlay',
);

final profileWidgetBuilds = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.profileWidgetBuilds',
  title: 'Track Widget Builds',
  enabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/trackwidget-white.png',
    darkModeAsset: 'icons/trackwidget-dgrey.png',
  ),
  disabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/trackwidget-dgrey.png',
    darkModeAsset: 'icons/trackwidget-lgrey.png',
  ),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.performance,
  gaItem: analytics_constants.trackRebuilds,
  description: 'Adds an event to the timeline for every Widget built.',
  tooltip: '',
);

final profileRenderObjectPaints = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.profileRenderObjectPaints',
  title: 'Track Paints',
  enabledIcon: Icon(Icons.format_paint, size: defaultIconSize),
  disabledIcon: Icon(Icons.format_paint, size: defaultIconSize),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.performance,
  gaItem: analytics_constants.trackPaints,
  description: 'Adds an event to the timeline for every RenderObject painted.',
  tooltip: '',
);

final profileRenderObjectLayouts =
    ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.profileRenderObjectLayouts',
  title: 'Track Layouts',
  enabledIcon: Icon(Icons.auto_awesome_mosaic, size: defaultIconSize),
  disabledIcon: Icon(Icons.auto_awesome_mosaic, size: defaultIconSize),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.performance,
  gaItem: analytics_constants.trackLayouts,
  description: 'Adds an event to the timeline for every RenderObject layout.',
  tooltip: '',
);

final repaintRainbow = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.repaintRainbow',
  title: 'Highlight Repaints',
  enabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/repaints-white.png',
    darkModeAsset: 'icons/repaints-dgrey.png',
  ),
  disabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/repaints-dgrey.png',
    darkModeAsset: 'icons/repaints-lgrey.png',
  ),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.repaintRainbow,
  tooltip:
      'Show borders that change color when elements repaint. Useful for finding unnecessary repaints.',
  tooltipUrl:
      'https://flutter.dev/docs/development/tools/devtools/inspector#highlight-repaints',
);

final slowAnimations = ToggleableServiceExtensionDescription<num>._(
  extension: 'ext.flutter.timeDilation',
  title: 'Slow Animations',
  enabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/slow-white.png',
    darkModeAsset: 'icons/slow-dgrey.png',
  ),
  disabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/slow-dgrey.png',
    darkModeAsset: 'icons/slow-lgrey.png',
  ),
  enabledValue: 5.0,
  disabledValue: 1.0,
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.slowAnimation,
  tooltip: 'Run animations 5 times slower to help fine-tune them.',
  tooltipUrl:
      'https://flutter.dev/docs/development/tools/devtools/inspector#slow-animations',
);

final togglePlatformMode = ServiceExtensionDescription<String>(
  extension: 'ext.flutter.platformOverride',
  title: 'Override target platform',
  enabledIcon: const AssetImageIcon(asset: 'icons/phone@2x.png'),
  values: ['iOS', 'android', 'fuchsia', 'macOS', 'linux'],
  displayValues: [
    'Platform: iOS',
    'Platform: Android',
    'Platform: Fuchsia',
    'Platform: MacOS',
    'Platform: Linux'
  ],
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.togglePlatform,
  tooltip: 'Override Target Platform',
);

final disableClipLayers = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.debugDisableClipLayers',
  inverted: true,
  title: 'Render Clip layers',
  enabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/slow-white.png',
    darkModeAsset: 'icons/slow-dgrey.png',
  ),
  disabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/slow-dgrey.png',
    darkModeAsset: 'icons/slow-lgrey.png',
  ),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.performance,
  gaItem: analytics_constants.disableOpacityLayersOption,
  description: 'Render all clipping effects during paint',
  tooltip: '''Disable this option to check whether excessive use of clipping is
affecting performance. If performance improves with this option
disabled, try to reduce the use of clipping effects in your app.''',
);

final disableOpacityLayers = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.debugDisableOpacityLayers',
  inverted: true,
  title: 'Render Opacity layers',
  enabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/slow-white.png',
    darkModeAsset: 'icons/slow-dgrey.png',
  ),
  disabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/slow-dgrey.png',
    darkModeAsset: 'icons/slow-lgrey.png',
  ),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.performance,
  gaItem: analytics_constants.disableOpacityLayersOption,
  description: 'Render all opacity effects during paint',
  tooltip: '''Disable this option to check whether excessive use of opacity
effects is affecting performance. If performance improves with this
option disabled, try to reduce the use of opacity effects in your app.''',
);

final disablePhysicalShapeLayers =
    ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.debugDisablePhysicalShapeLayers',
  inverted: true,
  title: 'Render Physical Shape layers',
  enabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/slow-white.png',
    darkModeAsset: 'icons/slow-dgrey.png',
  ),
  disabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/slow-dgrey.png',
    darkModeAsset: 'icons/slow-lgrey.png',
  ),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.performance,
  gaItem: analytics_constants.disableOpacityLayersOption,
  description: 'Render all physical modeling effects during paint',
  tooltip: '''Disable this option to check whether excessive use of physical 
modeling effects is affecting performance (shadows, elevations, etc.). 
If performance improves with this option disabled, try to reduce the 
use of physical modeling effects in your app.''',
);

final httpEnableTimelineLogging = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.dart.io.httpEnableTimelineLogging',
  title: 'Whether HTTP timeline logging is enabled',
  enabledIcon: const Placeholder(),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: null,
  gaItem: null,
  shouldCallOnAllIsolates: true,
  tooltip: 'Toggle HTTP timeline logging',
);

final socketProfiling = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.dart.io.socketProfilingEnabled',
  title: 'Whether socket profiling is enabled',
  enabledIcon: const Placeholder(),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: null,
  gaItem: null,
  shouldCallOnAllIsolates: true,
  tooltip: 'Toggle socket profiling',
);

// Legacy extension to show the inspector and enable inspector select mode.
final toggleOnDeviceWidgetInspector =
    ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.inspector.show',
  // Technically this enables the on-device widget inspector but for older
  // versions of package:flutter it makes sense to describe this extension as
  // toggling widget select mode as it is the only way to toggle that mode.
  title: 'Select Widget Mode',
  enabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/widget-select-white.png',
    darkModeAsset: 'icons/widget-select-dgrey.png',
  ),
  disabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/widget-select-dgrey.png',
    darkModeAsset: 'icons/widget-select-lgrey.png',
  ),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.showOnDeviceInspector,
  tooltip: 'Toggle select widget mode',
);

/// Toggle whether interacting with the device selects widgets or triggers
/// normal interactions.
final toggleSelectWidgetMode = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.inspector.selectMode',
  title: 'Select widget mode',
  enabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/widget-select-white.png',
    darkModeAsset: 'icons/widget-select-dgrey.png',
  ),
  disabledIcon: const ThemedImageIcon(
    lightModeAsset: 'icons/widget-select-dgrey.png',
    darkModeAsset: 'icons/widget-select-lgrey.png',
  ),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.selectWidgetMode,
  tooltip: 'Toggle select widget mode',
);

/// Toggle whether the inspector on-device overlay is enabled.
///
/// When available, the inspector overlay can be enabled at any time as it will
/// not interfere with user interaction with the app unless inspector select
/// mode is triggered.
final enableOnDeviceInspector = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.inspector.enable',
  title: 'Enable on-device inspector',
  enabledIcon: const AssetImageIcon(asset: 'icons/general/locate@2x.png'),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.enableOnDeviceInspector,
  tooltip: 'Toggle on-device inspector',
);

final structuredErrors = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.inspector.structuredErrors',
  title: 'Show structured errors',
  enabledIcon: const AssetImageIcon(asset: 'icons/perf/RedExcl@2x.png'),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.logging,
  gaItem: analytics_constants.structuredErrors,
  tooltip: 'Toggle showing structured errors for Flutter framework issues',
);

final trackRebuildWidgets = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.inspector.trackRebuildDirtyWidgets',
  title: 'Show Rebuild Counts',
  enabledIcon: const AssetImageIcon(asset: 'icons/widget_tree@2x.png'),
  enabledValue: true,
  disabledValue: false,
  tooltip: 'Show widget rebuild counts since the last reload',
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.trackRebuildWidgets,
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
  trackRebuildWidgets,
  disableClipLayers,
  disableOpacityLayers,
  disablePhysicalShapeLayers,
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

bool isUnsafeBeforeFirstFlutterFrame(String? extensionName) {
  return _unsafeBeforeFirstFrameFlutterExtensions.contains(extensionName);
}

bool isFlutterExtension(String extensionName) {
  return extensionName.startsWith('ext.flutter.');
}

bool isDartIoExtension(String extensionName) {
  return extensionName.startsWith('ext.dart.io.');
}
