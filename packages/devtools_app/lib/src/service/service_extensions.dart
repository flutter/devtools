// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library service_extensions;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../shared/analytics/constants.dart' as gac;

const _dartIOExtensionPrefix = 'ext.dart.io.';
const _flutterExtensionPrefix = 'ext.flutter.';
const inspectorExtensionPrefix = 'ext.flutter.inspector';

// Each service extension needs to be added to [_extensionDescriptions].
class ToggleableServiceExtensionDescription<T>
    extends ServiceExtensionDescription {
  ToggleableServiceExtensionDescription._({
    super.iconAsset,
    super.iconData,
    required super.extension,
    required super.title,
    required T enabledValue,
    required T disabledValue,
    required super.gaScreenName,
    required super.gaItem,
    required super.tooltip,
    super.description,
    super.documentationUrl,
    super.gaDocsItem,
    super.shouldCallOnAllIsolates = false,
    this.inverted = false,
  }) : super(values: [enabledValue, disabledValue]);

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
    this.iconAsset,
    this.iconData,
    List<String>? displayValues,
    required this.extension,
    required this.title,
    required this.values,
    required this.gaScreenName,
    required this.gaItem,
    required this.tooltip,
    this.description,
    this.documentationUrl,
    this.gaDocsItem,
    this.shouldCallOnAllIsolates = false,
  })  : displayValues =
            displayValues ?? values.map((v) => v.toString()).toList(),
        assert((iconAsset == null) != (iconData == null)),
        assert((documentationUrl == null) == (gaDocsItem == null));

  final String extension;

  final String title;

  final String? iconAsset;

  final IconData? iconData;

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

  final String? documentationUrl;

  final String? gaDocsItem;
}

final debugAllowBanner = ToggleableServiceExtensionDescription<bool>._(
  extension:
      '$_flutterExtensionPrefix${WidgetsServiceExtensions.debugAllowBanner.name}',
  title: 'Debug Banner',
  iconAsset: 'icons/debug_banner@2x.png',
  enabledValue: true,
  disabledValue: false,
  gaScreenName: gac.inspector,
  gaItem: gac.debugBanner,
  tooltip: 'Toggle Debug Banner',
);

final invertOversizedImages = ToggleableServiceExtensionDescription<bool>._(
  extension:
      '$_flutterExtensionPrefix${RenderingServiceExtensions.invertOversizedImages.name}',
  title: 'Highlight Oversized Images',
  iconAsset: 'icons/images-white.png',
  enabledValue: true,
  disabledValue: false,
  gaScreenName: gac.inspector,
  gaItem: gac.highlightOversizedImages,
  tooltip:
      'Highlight images that are using too much memory by inverting colors and flipping them.',
  documentationUrl:
      'https://flutter.dev/docs/development/tools/devtools/inspector#highlight-oversized-images',
  gaDocsItem: gac.highlightOversizedImagesDocs,
);

final debugPaint = ToggleableServiceExtensionDescription<bool>._(
  extension:
      '$_flutterExtensionPrefix${RenderingServiceExtensions.debugPaint.name}',
  title: 'Show Guidelines',
  iconAsset: 'icons/guidelines-white.png',
  enabledValue: true,
  disabledValue: false,
  gaScreenName: gac.inspector,
  gaItem: gac.debugPaint,
  tooltip: 'Overlay guidelines to assist with fixing layout issues.',
  documentationUrl:
      'https://flutter.dev/docs/development/tools/devtools/inspector#show-guidelines',
  gaDocsItem: gac.debugPaintDocs,
);

final debugPaintBaselines = ToggleableServiceExtensionDescription<bool>._(
  extension:
      '$_flutterExtensionPrefix${RenderingServiceExtensions.debugPaintBaselinesEnabled.name}',
  title: 'Show Baselines',
  iconAsset: 'icons/baselines-white.png',
  enabledValue: true,
  disabledValue: false,
  gaScreenName: gac.inspector,
  gaItem: gac.paintBaseline,
  tooltip:
      'Show baselines, which are used to position text. Can be useful for checking if text is aligned.',
  documentationUrl:
      'https://flutter.dev/docs/development/tools/devtools/inspector#show-baselines',
  gaDocsItem: gac.paintBaselineDocs,
);

final performanceOverlay = ToggleableServiceExtensionDescription<bool>._(
  extension:
      '$_flutterExtensionPrefix${WidgetsServiceExtensions.showPerformanceOverlay.name}',
  title: 'Performance Overlay',
  iconAsset: 'icons/performance-white.png',
  enabledValue: true,
  disabledValue: false,
  gaScreenName: gac.performance,
  gaItem: gac.PerformanceEvents.performanceOverlay.name,
  tooltip: 'Overlay a performance chart on your app.',
  documentationUrl:
      'https://flutter.dev/docs/perf/rendering/ui-performance#the-performance-overlay',
  gaDocsItem: gac.PerformanceDocs.performanceOverlayDocs.name,
);

final profileWidgetBuilds = ToggleableServiceExtensionDescription<bool>._(
  extension:
      '$_flutterExtensionPrefix${WidgetsServiceExtensions.profileWidgetBuilds.name}',
  title: 'Track Widget Builds',
  iconAsset: 'icons/trackwidget-white.png',
  enabledValue: true,
  disabledValue: false,
  gaScreenName: gac.performance,
  gaItem: gac.PerformanceEvents.trackRebuilds.name,
  description: 'Adds an event to the timeline for every Widget built.',
  tooltip: '',
  documentationUrl:
      'https://docs.flutter.dev/development/tools/devtools/performance#track-widget-builds',
  gaDocsItem: gac.PerformanceDocs.trackWidgetBuildsDocs.name,
);

final profileUserWidgetBuilds = ToggleableServiceExtensionDescription<bool>._(
  extension:
      '$_flutterExtensionPrefix${WidgetsServiceExtensions.profileUserWidgetBuilds.name}',
  title: 'Track User-Created Widget Builds',
  iconAsset: 'icons/trackwidget-white.png',
  enabledValue: true,
  disabledValue: false,
  gaScreenName: gac.performance,
  gaItem: gac.PerformanceEvents.trackUserCreatedWidgetBuilds.name,
  description:
      'Adds an event to the timeline for every Widget created in user code.',
  tooltip: '',
);

final profileRenderObjectPaints = ToggleableServiceExtensionDescription<bool>._(
  extension:
      '$_flutterExtensionPrefix${RenderingServiceExtensions.profileRenderObjectPaints.name}',
  title: 'Track Paints',
  iconData: Icons.format_paint,
  enabledValue: true,
  disabledValue: false,
  gaScreenName: gac.performance,
  gaItem: gac.PerformanceEvents.trackPaints.name,
  description: 'Adds an event to the timeline for every RenderObject painted.',
  tooltip: '',
  documentationUrl:
      'https://docs.flutter.dev/development/tools/devtools/performance#track-paints',
  gaDocsItem: gac.PerformanceDocs.trackPaintsDocs.name,
);

final profileRenderObjectLayouts =
    ToggleableServiceExtensionDescription<bool>._(
  extension:
      '$_flutterExtensionPrefix${RenderingServiceExtensions.profileRenderObjectLayouts.name}',
  title: 'Track Layouts',
  iconData: Icons.auto_awesome_mosaic,
  enabledValue: true,
  disabledValue: false,
  gaScreenName: gac.performance,
  gaItem: gac.PerformanceEvents.trackLayouts.name,
  description: 'Adds an event to the timeline for every RenderObject layout.',
  tooltip: '',
  documentationUrl:
      'https://docs.flutter.dev/development/tools/devtools/performance#track-layouts',
  gaDocsItem: gac.PerformanceDocs.trackLayoutsDocs.name,
);

final repaintRainbow = ToggleableServiceExtensionDescription<bool>._(
  extension:
      '$_flutterExtensionPrefix${RenderingServiceExtensions.repaintRainbow.name}',
  title: 'Highlight Repaints',
  iconAsset: 'icons/repaints-white.png',
  enabledValue: true,
  disabledValue: false,
  gaScreenName: gac.inspector,
  gaItem: gac.repaintRainbow,
  tooltip:
      'Show borders that change color when elements repaint. Useful for finding unnecessary repaints.',
  documentationUrl:
      'https://flutter.dev/docs/development/tools/devtools/inspector#highlight-repaints',
  gaDocsItem: gac.repaintRainbowDocs,
);

final slowAnimations = ToggleableServiceExtensionDescription<num>._(
  extension:
      '$_flutterExtensionPrefix${SchedulerServiceExtensions.timeDilation.name}',
  title: 'Slow Animations',
  iconAsset: 'icons/slow-white.png',
  enabledValue: 5.0,
  disabledValue: 1.0,
  gaScreenName: gac.inspector,
  gaItem: gac.slowAnimation,
  tooltip: 'Run animations 5 times slower to help fine-tune them.',
  documentationUrl:
      'https://flutter.dev/docs/development/tools/devtools/inspector#slow-animations',
  gaDocsItem: gac.slowAnimationDocs,
);

final togglePlatformMode = ServiceExtensionDescription<String>(
  extension:
      '$_flutterExtensionPrefix${FoundationServiceExtensions.platformOverride.name}',
  title: 'Override target platform',
  iconAsset: 'icons/phone@2x.png',
  values: ['iOS', 'android', 'fuchsia', 'macOS', 'linux'],
  displayValues: [
    'Platform: iOS',
    'Platform: Android',
    'Platform: Fuchsia',
    'Platform: MacOS',
    'Platform: Linux',
  ],
  gaScreenName: gac.inspector,
  gaItem: gac.togglePlatform,
  tooltip: 'Override Target Platform',
);

final disableClipLayers = ToggleableServiceExtensionDescription<bool>._(
  extension:
      '$_flutterExtensionPrefix${RenderingServiceExtensions.debugDisableClipLayers.name}',
  inverted: true,
  title: 'Render Clip layers',
  iconData: Icons.cut_outlined,
  enabledValue: true,
  disabledValue: false,
  gaScreenName: gac.performance,
  gaItem: gac.PerformanceEvents.disableClipLayers.name,
  description: 'Render all clipping effects during paint.',
  tooltip: '''Disable this option to check whether excessive use of clipping is
affecting performance. If performance improves with this option
disabled, try to reduce the use of clipping effects in your app.''',
  documentationUrl:
      'https://docs.flutter.dev/development/tools/devtools/performance#more-debugging-options',
  gaDocsItem: gac.PerformanceDocs.disableClipLayersDocs.name,
);

final disableOpacityLayers = ToggleableServiceExtensionDescription<bool>._(
  extension:
      '$_flutterExtensionPrefix${RenderingServiceExtensions.debugDisableOpacityLayers.name}',
  inverted: true,
  title: 'Render Opacity layers',
  iconData: Icons.opacity,
  enabledValue: true,
  disabledValue: false,
  gaScreenName: gac.performance,
  gaItem: gac.PerformanceEvents.disableOpacityLayers.name,
  description: 'Render all opacity effects during paint.',
  tooltip: '''Disable this option to check whether excessive use of opacity
effects is affecting performance. If performance improves with this
option disabled, try to reduce the use of opacity effects in your app.''',
  documentationUrl:
      'https://docs.flutter.dev/development/tools/devtools/performance#more-debugging-options',
  gaDocsItem: gac.PerformanceDocs.disableOpacityLayersDocs.name,
);

final disablePhysicalShapeLayers =
    ToggleableServiceExtensionDescription<bool>._(
  extension:
      '$_flutterExtensionPrefix${RenderingServiceExtensions.debugDisablePhysicalShapeLayers.name}',
  inverted: true,
  title: 'Render Physical Shape layers',
  iconData: Icons.format_shapes,
  enabledValue: true,
  disabledValue: false,
  gaScreenName: gac.performance,
  gaItem: gac.PerformanceEvents.disablePhysicalShapeLayers.name,
  description: 'Render all physical modeling effects during paint.',
  tooltip: '''Disable this option to check whether excessive use of physical
modeling effects is affecting performance (shadows, elevations, etc.).
If performance improves with this option disabled, try to reduce the
use of physical modeling effects in your app.''',
  documentationUrl:
      'https://docs.flutter.dev/development/tools/devtools/performance#more-debugging-options',
  gaDocsItem: gac.PerformanceDocs.disablePhysicalShapeLayersDocs.name,
);

final httpEnableTimelineLogging = ToggleableServiceExtensionDescription<bool>._(
  extension: '${_dartIOExtensionPrefix}httpEnableTimelineLogging',
  title: 'Whether HTTP timeline logging is enabled',
  iconData: Icons.http,
  enabledValue: true,
  disabledValue: false,
  gaScreenName: null,
  gaItem: null,
  shouldCallOnAllIsolates: true,
  tooltip: 'Toggle HTTP timeline logging',
);

final socketProfiling = ToggleableServiceExtensionDescription<bool>._(
  extension: '${_dartIOExtensionPrefix}socketProfilingEnabled',
  title: 'Whether socket profiling is enabled',
  iconData: Icons.outlet_outlined,
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
  extension:
      '$inspectorExtensionPrefix.${WidgetInspectorServiceExtensions.show.name}',
  // Technically this enables the on-device widget inspector but for older
  // versions of package:flutter it makes sense to describe this extension as
  // toggling widget select mode as it is the only way to toggle that mode.
  title: 'Select Widget Mode',
  iconAsset: 'icons/widget-select-white.png',
  enabledValue: true,
  disabledValue: false,
  gaScreenName: gac.inspector,
  gaItem: gac.showOnDeviceInspector,
  tooltip: 'Toggle select widget mode',
);

// TODO(kenz): remove this if it is not needed. According to the comments,
// [toggleOnDeviceWidgetInspector] should be the legacy extension, but that is
// the only extension available, and [toggleSelectWidgetMode] is not.
/// Toggle whether interacting with the device selects widgets or triggers
/// normal interactions.
final toggleSelectWidgetMode = ToggleableServiceExtensionDescription<bool>._(
  extension: '$inspectorExtensionPrefix.selectMode',
  title: 'Select widget mode',
  iconAsset: 'icons/widget-select-white.png',
  enabledValue: true,
  disabledValue: false,
  gaScreenName: gac.inspector,
  gaItem: gac.selectWidgetMode,
  tooltip: 'Toggle select widget mode',
);

// TODO(kenz): remove this if it is not needed. According to the comments,
// [toggleOnDeviceWidgetInspector] should be the legacy extension, but that is
// the only extension available, and [toggleSelectWidgetMode] is not. And in
// DevTools code, [enableOnDeviceInspector] is only called when
// [toggleSelectWidgetMode] is available.
/// Toggle whether the inspector on-device overlay is enabled.
///
/// When available, the inspector overlay can be enabled at any time as it will
/// not interfere with user interaction with the app unless inspector select
/// mode is triggered.
final enableOnDeviceInspector = ToggleableServiceExtensionDescription<bool>._(
  extension: '$inspectorExtensionPrefix.enable',
  title: 'Enable on-device inspector',
  iconAsset: 'icons/general/locate@2x.png',
  enabledValue: true,
  disabledValue: false,
  gaScreenName: gac.inspector,
  gaItem: gac.enableOnDeviceInspector,
  tooltip: 'Toggle on-device inspector',
);

final structuredErrors = ToggleableServiceExtensionDescription<bool>._(
  extension:
      '$inspectorExtensionPrefix.${WidgetInspectorServiceExtensions.structuredErrors.name}',
  title: 'Show structured errors',
  iconAsset: 'icons/perf/RedExcl@2x.png',
  enabledValue: true,
  disabledValue: false,
  gaScreenName: gac.logging,
  gaItem: gac.structuredErrors,
  tooltip: 'Toggle showing structured errors for Flutter framework issues',
);

final trackRebuildWidgets = ToggleableServiceExtensionDescription<bool>._(
  extension:
      '$inspectorExtensionPrefix.${WidgetInspectorServiceExtensions.trackRebuildDirtyWidgets.name}',
  title: 'Track widget build counts',
  iconAsset: 'icons/inspector/diagram@2x.png',
  enabledValue: true,
  disabledValue: false,
  description: 'Tells you what has been rebuilt in your app\'s current screen.',
  tooltip: 'Show widget rebuild counts since the last reload',
  gaScreenName: gac.inspector,
  gaItem: gac.trackRebuildWidgets,
);

// This extensions below should never be displayed as a button so does not need
// a ServiceExtensionDescription object.
final String didSendFirstFrameEvent =
    '$_flutterExtensionPrefix${WidgetsServiceExtensions.didSendFirstFrameEvent.name}';

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
    { for (var extension in _extensionDescriptions) extension.extension : extension };

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
  return extensionName.startsWith(_flutterExtensionPrefix);
}

bool isDartIoExtension(String extensionName) {
  return extensionName.startsWith(_dartIOExtensionPrefix);
}
