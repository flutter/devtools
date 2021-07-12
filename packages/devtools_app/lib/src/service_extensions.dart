// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library service_extensions;

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'analytics/constants.dart' as analytics_constants;
import 'theme.dart';
import 'ui/icons.dart';
import 'ui/service_extension_widgets.dart';

typedef TooltipBuilder = Widget Function(bool isSelected, Widget child);

// Each service extension needs to be added to [_extensionDescriptions].
class ToggleableServiceExtensionDescription<T>
    extends ServiceExtensionDescription {
  ToggleableServiceExtensionDescription._({
    Widget icon,
    @required String extension,
    @required String description,
    @required T enabledValue,
    @required T disabledValue,
    @required TooltipBuilder tooltipBuilder,
    @required String gaScreenName,
    @required String gaItem,
    bool shouldCallOnAllIsolates = false,
  }) : super(
          extension: extension,
          description: description,
          icon: icon,
          values: [enabledValue, disabledValue],
          tooltipBuilder: tooltipBuilder,
          gaScreenName: gaScreenName,
          gaItem: gaItem,
          shouldCallOnAllIsolates: shouldCallOnAllIsolates,
        );

  static const enabledValueIndex = 0;

  static const disabledValueIndex = 1;

  T get enabledValue => values[enabledValueIndex];

  T get disabledValue => values[disabledValueIndex];
}

class ServiceExtensionDescription<T> {
  ServiceExtensionDescription({
    this.icon,
    List<String> displayValues,
    @required this.extension,
    @required this.description,
    @required this.values,
    @required this.tooltipBuilder,
    @required this.gaScreenName,
    @required this.gaItem,
    this.shouldCallOnAllIsolates = false,
  }) : displayValues =
            displayValues ?? values.map((v) => v.toString()).toList();

  final String extension;

  final String description;

  final Widget icon;

  final List<T> values;

  final List<String> displayValues;

  final String gaScreenName; // Analytics screen (screen name where item lives).

  final String gaItem; // Analytics item name (toggleable item's name).

  final bool shouldCallOnAllIsolates;

  final TooltipBuilder tooltipBuilder;
}

final debugAllowBanner = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.debugAllowBanner',
  description: 'Debug Banner',
  icon: createImageIcon('icons/debug_banner@2x.png'),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.debugBanner,
  tooltipBuilder: (bool isSelected, Widget child) {
    return BasicTooltip(
      message: isSelected ? 'Hide Debug Banner' : 'Show Debug Banner',
      child: child,
    );
  },
);

final invertOversizedImages = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.invertOversizedImages',
  description: 'Invert Oversized Images',
  icon: const Icon(Icons.image, size: actionsIconSize),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.debugBanner,
  tooltipBuilder: (bool isSelected, Widget child) {
    return RichTooltip(
      message:
          'Highlights images that are using too much memory by inverting colors and flipping them.',
      // TODO: Correct URL
      url:
          'https://flutter.dev/docs/development/tools/devtools/inspector#debugging-layout-issues-visually',
      child: child,
    );
  },
);

final debugPaint = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.debugPaint',
  description: 'Show Guidelines',
  icon: createImageIcon('icons/debug_paint@2x.png'),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.debugPaint,
  tooltipBuilder: (bool isSelected, Widget child) {
    return RichTooltip(
      message: 'Overlay guidelines to assist with fixing layout issues.',
      // TODO: Correct URL
      url:
          'https://flutter.dev/docs/development/tools/devtools/inspector#debugging-layout-issues-visually',
      child: child,
    );
  },
);

final debugPaintBaselines = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.debugPaintBaselinesEnabled',
  description: 'Paint Baselines',
  icon: createImageIcon('icons/inspector/textArea@2x.png'),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.paintBaseline,
  tooltipBuilder: (bool isSelected, Widget child) {
    return RichTooltip(
      message:
          'Show baselines, which are used for aligning text. Can be useful for checking if text is aligned.',
      // TODO: Correct URL
      url:
          'https://flutter.dev/docs/development/tools/devtools/inspector#debugging-layout-issues-visually',
      child: child,
    );
  },
);

final performanceOverlay = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.showPerformanceOverlay',
  description: 'Performance Overlay',
  icon: createImageIcon('icons/general/performance_overlay@2x.png'),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.performanceOverlay,
  tooltipBuilder: (bool isSelected, Widget child) {
    return BasicTooltip(
      message:
          isSelected ? 'Hide Performance Overlay' : 'Show Performance Overlay',
      child: child,
    );
  },
);

final profileWidgetBuilds = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.profileWidgetBuilds',
  description: 'Track Widget Builds',
  icon: createImageIcon('icons/widget_tree@2x.png'),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.performance,
  gaItem: analytics_constants.trackRebuilds,
  tooltipBuilder: (bool isSelected, Widget child) {
    return BasicTooltip(
      message: isSelected
          ? 'Disable tracking widget builds'
          : 'Enable tracking widget builds',
      child: child,
    );
  },
);

final repaintRainbow = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.repaintRainbow',
  description: 'Repaint Rainbow',
  icon: createImageIcon('icons/repaint_rainbow@2x.png'),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.repaintRainbow,
  tooltipBuilder: (bool isSelected, Widget child) {
    return RichTooltip(
      message:
          'Show borders that change color when elements repaint. Useful for finding unnecessary repaints.',
      // TODO: Correct URL
      url:
          'https://flutter.dev/docs/development/tools/devtools/inspector#debugging-layout-issues-visually',
      child: child,
    );
  },
);

final slowAnimations = ToggleableServiceExtensionDescription<num>._(
  extension: 'ext.flutter.timeDilation',
  description: 'Slow Animations',
  icon: createImageIcon('icons/history@2x.png'),
  enabledValue: 5.0,
  disabledValue: 1.0,
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.slowAnimation,
  tooltipBuilder: (bool isSelected, Widget child) {
    return RichTooltip(
      message: 'Run animations 5 times slower to help fine-tune them.',
      // TODO: Correct URL
      url:
          'https://flutter.dev/docs/development/tools/devtools/inspector#debugging-layout-issues-visually',
      child: child,
    );
  },
);

final togglePlatformMode = ServiceExtensionDescription<String>(
  extension: 'ext.flutter.platformOverride',
  description: 'Override target platform',
  icon: createImageIcon('icons/phone@2x.png'),
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
  tooltipBuilder: (bool isSelected, Widget child) {
    return BasicTooltip(
      message: 'Override Target Platform',
      child: child,
    );
  },
);

final httpEnableTimelineLogging = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.dart.io.httpEnableTimelineLogging',
  description: 'Whether HTTP timeline logging is enabled',
  enabledValue: true,
  disabledValue: false,
  gaScreenName: null,
  gaItem: null,
  shouldCallOnAllIsolates: true,
  tooltipBuilder: (bool isSelected, Widget child) {
    return BasicTooltip(
      message: isSelected
          ? 'HTTP timeline logging enabled'
          : 'HTTP timeline logging disabled',
      child: child,
    );
  },
);

final socketProfiling = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.dart.io.socketProfilingEnabled',
  description: 'Whether socket profiling is enabled',
  enabledValue: true,
  disabledValue: false,
  gaScreenName: null,
  gaItem: null,
  shouldCallOnAllIsolates: true,
  tooltipBuilder: (bool isSelected, Widget child) {
    return BasicTooltip(
      message:
          isSelected ? 'Socket profiling enabled' : 'Socket profiling disabled',
      child: child,
    );
  },
);

// Legacy extension to show the inspector and enable inspector select mode.
final toggleOnDeviceWidgetInspector =
    ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.inspector.show',
  // Technically this enables the on-device widget inspector but for older
  // versions of package:flutter it makes sense to describe this extension as
  // toggling widget select mode as it is the only way to toggle that mode.
  description: 'Select Widget Mode',
  icon: createImageIcon('icons/general/locate@2x.png'),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.showOnDeviceInspector,
  tooltipBuilder: (bool isSelected, Widget child) {
    return BasicTooltip(
      message: isSelected
          ? 'Disable select widget mode'
          : 'Enable select widget mode',
      child: child,
    );
  },
);

/// Toggle whether interacting with the device selects widgets or triggers
/// normal interactions.
final toggleSelectWidgetMode = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.inspector.selectMode',
  description: 'Select widget mode',
  icon: createImageIcon('icons/general/locate@2x.png'),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.selectWidgetMode,
  tooltipBuilder: (bool isSelected, Widget child) {
    return BasicTooltip(
      message:
          isSelected ? 'Exit select widget mode' : 'Enter select widget mode',
      child: child,
    );
  },
);

/// Toggle whether the inspector on-device overlay is enabled.
///
/// When available, the inspector overlay can be enabled at any time as it will
/// not interfere with user interaction with the app unless inspector select
/// mode is triggered.
final enableOnDeviceInspector = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.inspector.enable',
  description: 'Enable on-device inspector',
  icon: createImageIcon('icons/general/locate@2x.png'),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.inspector,
  gaItem: analytics_constants.enableOnDeviceInspector,
  tooltipBuilder: (bool isSelected, Widget child) {
    return BasicTooltip(
      message:
          isSelected ? 'Exit on-device inspector' : 'Enter on-device inspector',
      child: child,
    );
  },
);

final structuredErrors = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.inspector.structuredErrors',
  description: 'Show structured errors',
  icon: createImageIcon('icons/perf/RedExcl@2x.png'),
  enabledValue: true,
  disabledValue: false,
  gaScreenName: analytics_constants.logging,
  gaItem: analytics_constants.structuredErrors,
  tooltipBuilder: (bool isSelected, Widget child) {
    return BasicTooltip(
      message: isSelected
          ? 'Disable structured errors for Flutter framework issues'
          : 'Show structured errors for Flutter framework issues',
      child: child,
    );
  },
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
