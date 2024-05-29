// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/service_extensions.dart' as extensions;
import 'package:flutter/material.dart';

import '../shared/analytics/constants.dart' as gac;

/// Interface that service extension objects used in DevTools must implement.
abstract class ServiceExtensionInterface {
  String get title;

  String? get iconAsset;

  IconData? get iconData;

  List<String> get displayValues;

  /// Analytics screen (screen name where item lives).
  String? get gaScreenName;

  String? get gaItem;

  String get tooltip;

  String? get description;

  String? get documentationUrl;

  String? get gaDocsItem;

  String get gaItemTooltipLink;
}

/// A subclass of [extensions.ToggleableServiceExtension] that includes metadata
/// for displaying and interacting with a toggleable service extension in the
/// DevTools UI.
class ToggleableServiceExtensionDescription<T extends Object> extends extensions
    .ToggleableServiceExtension implements ServiceExtensionInterface {
  ToggleableServiceExtensionDescription._({
    required super.extension,
    required super.enabledValue,
    required super.disabledValue,
    required this.title,
    required this.gaScreenName,
    required this.gaItem,
    required this.tooltip,
    super.shouldCallOnAllIsolates = false,
    super.inverted = false,
    this.description,
    this.documentationUrl,
    this.gaDocsItem,
    this.iconAsset,
    this.iconData,
  })  : displayValues =
            [enabledValue, disabledValue].map((v) => v.toString()).toList(),
        assert((iconAsset == null) != (iconData == null)),
        assert((documentationUrl == null) == (gaDocsItem == null));

  factory ToggleableServiceExtensionDescription.from(
    extensions.ToggleableServiceExtension<T> extension, {
    required String title,
    required String? gaScreenName,
    required String? gaItem,
    required String tooltip,
    String? description,
    String? documentationUrl,
    String? gaDocsItem,
    String? iconAsset,
    IconData? iconData,
  }) {
    return ToggleableServiceExtensionDescription._(
      extension: extension.extension,
      enabledValue: extension.enabledValue,
      disabledValue: extension.disabledValue,
      shouldCallOnAllIsolates: extension.shouldCallOnAllIsolates,
      inverted: extension.inverted,
      title: title,
      gaScreenName: gaScreenName,
      gaItem: gaItem,
      tooltip: tooltip,
      description: description,
      documentationUrl: documentationUrl,
      gaDocsItem: gaDocsItem,
      iconAsset: iconAsset,
      iconData: iconData,
    );
  }

  @override
  final String title;

  @override
  final String? iconAsset;

  @override
  final IconData? iconData;

  @override
  final List<String> displayValues;

  @override
  final String? gaScreenName;

  @override
  final String? gaItem;

  @override
  final String tooltip;

  @override
  final String? description;

  @override
  final String? documentationUrl;

  @override
  final String? gaDocsItem;

  @override
  String get gaItemTooltipLink => '${gaItem}TooltipLink';
}

/// A subclass of [extensions.ServiceExtension] that includes metadata for
/// displaying and interacting with a service extension in the DevTools UI.
class ServiceExtensionDescription<T> extends extensions.ServiceExtension<T>
    implements ServiceExtensionInterface {
  ServiceExtensionDescription._({
    required super.extension,
    required super.values,
    super.shouldCallOnAllIsolates = false,
    this.iconAsset,
    this.iconData,
    List<String>? displayValues,
    required this.title,
    required this.gaScreenName,
    required this.gaItem,
    required this.tooltip,
    this.description,
    this.documentationUrl,
    this.gaDocsItem,
  })  : displayValues =
            displayValues ?? values.map((v) => v.toString()).toList(),
        assert((iconAsset == null) != (iconData == null)),
        assert((documentationUrl == null) == (gaDocsItem == null));

  factory ServiceExtensionDescription.from(
    extensions.ServiceExtension<T> extension, {
    required String title,
    required String? gaScreenName,
    required String? gaItem,
    required String tooltip,
    String? description,
    String? documentationUrl,
    String? gaDocsItem,
    String? iconAsset,
    IconData? iconData,
    List<String>? displayValues,
  }) {
    return ServiceExtensionDescription._(
      extension: extension.extension,
      values: extension.values,
      shouldCallOnAllIsolates: extension.shouldCallOnAllIsolates,
      title: title,
      gaScreenName: gaScreenName,
      gaItem: gaItem,
      tooltip: tooltip,
      description: description,
      documentationUrl: documentationUrl,
      gaDocsItem: gaDocsItem,
      iconAsset: iconAsset,
      iconData: iconData,
      displayValues: displayValues,
    );
  }

  @override
  final String title;

  @override
  final String? iconAsset;

  @override
  final IconData? iconData;

  @override
  final List<String> displayValues;

  @override
  final String? gaScreenName;

  @override
  final String? gaItem;

  @override
  final String tooltip;

  @override
  final String? description;

  @override
  final String? documentationUrl;

  @override
  final String? gaDocsItem;

  @override
  String get gaItemTooltipLink => '${gaItem}TooltipLink';
}

final debugAllowBanner = ToggleableServiceExtensionDescription<bool>.from(
  extensions.debugAllowBanner,
  title: 'Debug Banner',
  iconAsset: 'icons/debug_banner@2x.png',
  gaScreenName: gac.inspector,
  gaItem: gac.debugBanner,
  tooltip: 'Toggle Debug Banner',
);

final invertOversizedImages = ToggleableServiceExtensionDescription<bool>.from(
  extensions.invertOversizedImages,
  title: 'Highlight Oversized Images',
  iconAsset: 'icons/images-white.png',
  gaScreenName: gac.inspector,
  gaItem: gac.highlightOversizedImages,
  tooltip:
      'Highlight images that are using too much memory by inverting colors and flipping them.',
  documentationUrl:
      'https://flutter.dev/docs/development/tools/devtools/inspector#highlight-oversized-images',
  gaDocsItem: gac.highlightOversizedImagesDocs,
);

final debugPaint = ToggleableServiceExtensionDescription<bool>.from(
  extensions.debugPaint,
  title: 'Show Guidelines',
  iconAsset: 'icons/guidelines-white.png',
  gaScreenName: gac.inspector,
  gaItem: gac.debugPaint,
  tooltip: 'Overlay guidelines to assist with fixing layout issues.',
  documentationUrl:
      'https://flutter.dev/docs/development/tools/devtools/inspector#show-guidelines',
  gaDocsItem: gac.debugPaintDocs,
);

final debugPaintBaselines = ToggleableServiceExtensionDescription<bool>.from(
  extensions.debugPaintBaselines,
  title: 'Show Baselines',
  iconAsset: 'icons/baselines-white.png',
  gaScreenName: gac.inspector,
  gaItem: gac.paintBaseline,
  tooltip:
      'Show baselines, which are used to position text. Can be useful for checking if text is aligned.',
  documentationUrl:
      'https://flutter.dev/docs/development/tools/devtools/inspector#show-baselines',
  gaDocsItem: gac.paintBaselineDocs,
);

final performanceOverlay = ToggleableServiceExtensionDescription<bool>.from(
  extensions.performanceOverlay,
  title: 'Performance Overlay',
  iconAsset: 'icons/performance-white.png',
  gaScreenName: gac.performance,
  gaItem: gac.PerformanceEvents.performanceOverlay.name,
  tooltip: 'Overlay a performance chart on your app.',
  documentationUrl:
      'https://flutter.dev/docs/perf/rendering/ui-performance#the-performance-overlay',
  gaDocsItem: gac.PerformanceDocs.performanceOverlayDocs.name,
);

final profileWidgetBuilds = ToggleableServiceExtensionDescription<bool>.from(
  extensions.profileWidgetBuilds,
  title: 'Track widget builds',
  iconAsset: 'icons/trackwidget-white.png',
  gaScreenName: gac.performance,
  gaItem: gac.PerformanceEvents.trackRebuilds.name,
  description: 'Adds an event to the timeline for every Widget built.',
  tooltip: '',
  documentationUrl:
      'https://docs.flutter.dev/development/tools/devtools/performance#track-widget-builds',
  gaDocsItem: gac.PerformanceDocs.trackWidgetBuildsDocs.name,
);

final profileUserWidgetBuilds =
    ToggleableServiceExtensionDescription<bool>.from(
  extensions.profileUserWidgetBuilds,
  title: 'Track user-created widget builds',
  iconAsset: 'icons/trackwidget-white.png',
  gaScreenName: gac.performance,
  gaItem: gac.PerformanceEvents.trackUserCreatedWidgetBuilds.name,
  description:
      'Adds an event to the timeline for every Widget created in user code.',
  tooltip: '',
);

final profileRenderObjectPaints =
    ToggleableServiceExtensionDescription<bool>.from(
  extensions.profileRenderObjectPaints,
  title: 'Track paints',
  iconData: Icons.format_paint,
  gaScreenName: gac.performance,
  gaItem: gac.PerformanceEvents.trackPaints.name,
  description: 'Adds an event to the timeline for every RenderObject painted.',
  tooltip: '',
  documentationUrl:
      'https://docs.flutter.dev/development/tools/devtools/performance#track-paints',
  gaDocsItem: gac.PerformanceDocs.trackPaintsDocs.name,
);

final profileRenderObjectLayouts =
    ToggleableServiceExtensionDescription<bool>.from(
  extensions.profileRenderObjectLayouts,
  title: 'Track layouts',
  iconData: Icons.auto_awesome_mosaic,
  gaScreenName: gac.performance,
  gaItem: gac.PerformanceEvents.trackLayouts.name,
  description: 'Adds an event to the timeline for every RenderObject layout.',
  tooltip: '',
  documentationUrl:
      'https://docs.flutter.dev/development/tools/devtools/performance#track-layouts',
  gaDocsItem: gac.PerformanceDocs.trackLayoutsDocs.name,
);

final repaintRainbow = ToggleableServiceExtensionDescription<bool>.from(
  extensions.repaintRainbow,
  title: 'Highlight Repaints',
  iconAsset: 'icons/repaints-white.png',
  gaScreenName: gac.inspector,
  gaItem: gac.repaintRainbow,
  tooltip:
      'Show borders that change color when elements repaint. Useful for finding unnecessary repaints.',
  documentationUrl:
      'https://flutter.dev/docs/development/tools/devtools/inspector#highlight-repaints',
  gaDocsItem: gac.repaintRainbowDocs,
);

final slowAnimations = ToggleableServiceExtensionDescription<num>.from(
  extensions.slowAnimations,
  title: 'Slow Animations',
  iconAsset: 'icons/slow-white.png',
  gaScreenName: gac.inspector,
  gaItem: gac.slowAnimation,
  tooltip: 'Run animations 5 times slower to help fine-tune them.',
  documentationUrl:
      'https://flutter.dev/docs/development/tools/devtools/inspector#slow-animations',
  gaDocsItem: gac.slowAnimationDocs,
);

final togglePlatformMode = ServiceExtensionDescription<String>.from(
  extensions.togglePlatformMode,
  title: 'Override target platform',
  iconAsset: 'icons/phone@2x.png',
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

final disableClipLayers = ToggleableServiceExtensionDescription<bool>.from(
  extensions.disableClipLayers,
  title: 'Render Clip layers',
  iconData: Icons.cut_outlined,
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

final disableOpacityLayers = ToggleableServiceExtensionDescription<bool>.from(
  extensions.disableOpacityLayers,
  title: 'Render Opacity layers',
  iconData: Icons.opacity,
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
    ToggleableServiceExtensionDescription<bool>.from(
  extensions.disablePhysicalShapeLayers,
  title: 'Render Physical Shape layers',
  iconData: Icons.format_shapes,
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

final httpEnableTimelineLogging =
    ToggleableServiceExtensionDescription<bool>.from(
  extensions.httpEnableTimelineLogging,
  title: 'Whether HTTP timeline logging is enabled',
  iconData: Icons.http,
  gaScreenName: null,
  gaItem: null,
  tooltip: 'Toggle HTTP timeline logging',
);

final socketProfiling = ToggleableServiceExtensionDescription<bool>.from(
  extensions.socketProfiling,
  title: 'Whether socket profiling is enabled',
  iconData: Icons.outlet_outlined,
  gaScreenName: null,
  gaItem: null,
  tooltip: 'Toggle socket profiling',
);

// Legacy extension to show the inspector and enable inspector select mode.
final toggleOnDeviceWidgetInspector =
    ToggleableServiceExtensionDescription<bool>.from(
  extensions.toggleOnDeviceWidgetInspector,
  // Technically this enables the on-device widget inspector but for older
  // versions of package:flutter it makes sense to describe this extension as
  // toggling widget select mode as it is the only way to toggle that mode.
  title: 'Select Widget Mode',
  iconAsset: 'icons/widget-select-white.png',
  gaScreenName: gac.inspector,
  gaItem: gac.showOnDeviceInspector,
  tooltip: 'Toggle select widget mode',
);

// TODO(kenz): remove this if it is not needed. According to the comments,
// [toggleOnDeviceWidgetInspector] should be the legacy extension, but that is
// the only extension available, and [toggleSelectWidgetMode] is not.
/// Toggle whether interacting with the device selects widgets or triggers
/// normal interactions.
final toggleSelectWidgetMode = ToggleableServiceExtensionDescription<bool>.from(
  extensions.toggleSelectWidgetMode,
  title: 'Select widget mode',
  iconAsset: 'icons/widget-select-white.png',
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
final enableOnDeviceInspector =
    ToggleableServiceExtensionDescription<bool>.from(
  extensions.enableOnDeviceInspector,
  title: 'Enable on-device inspector',
  iconAsset: 'icons/general/locate@2x.png',
  gaScreenName: gac.inspector,
  gaItem: gac.enableOnDeviceInspector,
  tooltip: 'Toggle on-device inspector',
);

final structuredErrors = ToggleableServiceExtensionDescription<bool>.from(
  extensions.structuredErrors,
  title: 'Show structured errors',
  iconAsset: 'icons/perf/RedExcl@2x.png',
  gaScreenName: gac.logging,
  gaItem: gac.structuredErrors,
  tooltip: 'Toggle showing structured errors for Flutter framework issues',
);

final trackWidgetBuildCounts = ToggleableServiceExtensionDescription<bool>.from(
  extensions.trackRebuildWidgets,
  title: 'Track widget build counts',
  iconAsset: 'icons/inspector/diagram@2x.png',
  gaScreenName: gac.performance,
  gaItem: gac.trackRebuildWidgets,
  description: 'Tracks widget build counts for each Flutter frame.',
  tooltip: '''Enable this option to see the widgets that were built in each 
Flutter frame using the Frame Analysis tool, or to see an aggregate
summary of these counts using the Rebuild Stats tool.''',
  // TODO(https://github.com/flutter/website/issues/10666): link docs
);

final profilePlatformChannels =
    ToggleableServiceExtensionDescription<bool>.from(
  extensions.profilePlatformChannels,
  title: 'Track platform channels',
  iconAsset: 'icons/trackwidget-white.png',
  gaScreenName: gac.performance,
  gaItem: gac.PerformanceEvents.profilePlatformChannels.name,
  description:
      'Adds an event to the timeline for platform channel messages (useful for '
      'apps with plugins). Also periodically prints platform channel '
      'statistics to console.',
  tooltip: '',
  documentationUrl:
      'https://docs.flutter.dev/platform-integration/platform-channels',
  gaDocsItem: gac.PerformanceDocs.platformChannelsDocs.name,
);
