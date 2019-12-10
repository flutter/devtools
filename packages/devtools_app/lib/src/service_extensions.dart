// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library service_extensions;

import 'package:meta/meta.dart';

import 'ui/analytics_constants.dart' as ga;
import 'ui/icons.dart';

// Each service extension needs to be added to [_extensionDescriptions].
class ToggleableServiceExtensionDescription<T>
    extends ServiceExtensionDescription {
  ToggleableServiceExtensionDescription._({
    DevToolsIcon icon,
    @required String extension,
    @required String description,
    @required T enabledValue,
    @required T disabledValue,
    @required String enabledTooltip,
    @required String disabledTooltip,
    @required String gaScreenName,
    @required String gaItem,
  }) : super(
          extension: extension,
          description: description,
          icon: icon,
          values: [enabledValue, disabledValue],
          tooltips: [enabledTooltip, disabledTooltip],
          gaScreenName: gaScreenName,
          gaItem: gaItem,
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
    this.icon,
    List<String> displayValues,
    @required this.extension,
    @required this.description,
    @required this.values,
    @required this.tooltips,
    @required this.gaScreenName,
    @required this.gaItem,
  }) : displayValues =
            displayValues ?? values.map((v) => v.toString()).toList();

  final String extension;

  final String description;

  final DevToolsIcon icon;

  final List<T> values;

  final List<String> displayValues;

  final List<String> tooltips;

  final String gaScreenName; // Analytics screen (screen name where item lives).

  final String gaItem; // Analytics item name (toggleable item's name).
}

final debugAllowBanner = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.debugAllowBanner',
  description: 'Debug Banner',
  icon: FlutterIcons.debugBanner,
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Hide Debug Banner',
  disabledTooltip: 'Show Debug Banner',
  gaScreenName: ga.inspector,
  gaItem: ga.debugBanner,
);

final debugPaint = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.debugPaint',
  description: 'Debug Paint',
  icon: FlutterIcons.debugPaint,
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Hide Debug Paint',
  disabledTooltip: 'Show Debug Paint',
  gaScreenName: ga.inspector,
  gaItem: ga.debugPaint,
);

final debugPaintBaselines = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.debugPaintBaselinesEnabled',
  description: 'Paint Baselines',
  icon: FlutterIcons.text,
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Hide Paint Baselines',
  disabledTooltip: 'Show Paint Baselines',
  gaScreenName: ga.inspector,
  gaItem: ga.paintBaseline,
);

final performanceOverlay = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.showPerformanceOverlay',
  description: 'Performance Overlay',
  icon: FlutterIcons.performanceOverlay,
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Hide Performance Overlay',
  disabledTooltip: 'Show Performance Overlay',
  gaScreenName: ga.inspector,
  gaItem: ga.performanceOverlay,
);

final profileWidgetBuilds = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.profileWidgetBuilds',
  description: 'Track Widget Rebuilds',
  icon: FlutterIcons.greyProgr,
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Do Not Track Widget Rebuilds',
  disabledTooltip: 'Track Widget Rebuilds',
  gaScreenName: ga.performance,
  gaItem: ga.trackRebuilds,
);

final repaintRainbow = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.repaintRainbow',
  description: 'Repaint Rainbow',
  icon: FlutterIcons.repaintRainbow,
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Hide Repaint Rainbow',
  disabledTooltip: 'Show Repaint Rainbow',
  gaScreenName: ga.inspector,
  gaItem: ga.repaintRainbow,
);

final slowAnimations = ToggleableServiceExtensionDescription<num>._(
  extension: 'ext.flutter.timeDilation',
  description: 'Slow Animations',
  icon: FlutterIcons.history,
  enabledValue: 5.0,
  disabledValue: 1.0,
  enabledTooltip: 'Disable Slow Animations',
  disabledTooltip: 'Enable Slow Animations',
  gaScreenName: ga.inspector,
  gaItem: ga.slowAnimation,
);

final togglePlatformMode = ServiceExtensionDescription<String>(
  extension: 'ext.flutter.platformOverride',
  description: 'Override target platform',
  icon: FlutterIcons.phone,
  values: ['iOS', 'android', 'fuchsia', 'macOS', 'linux'],
  displayValues: [
    'Platform: iOS',
    'Platform: Android',
    'Platform: Fuchsia',
    'Platform: MacOS',
    'Platform: Linux'
  ],
  tooltips: ['Override Target Platform'],
  gaScreenName: ga.inspector,
  gaItem: ga.togglePlatform,
);

// Legacy extension to show the inspector and enable inspector select mode.
final toggleOnDeviceWidgetInspector =
    ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.inspector.show',
  // Technically this enables the on-device widget inspector but for older
  // versions of package:flutter it makes sense to describe this extension as
  // toggling widget select mode as it is the only way to toggle that mode.
  description: 'Select Widget Mode',
  icon: FlutterIcons.locate,
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Disable select widget mode',
  disabledTooltip: 'Enable select widget mode',
  gaScreenName: ga.inspector,
  gaItem: ga.showOnDeviceInspector,
);

/// Toggle whether interacting with the device selects widgets or triggers
/// normal interactions.
final toggleSelectWidgetMode = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.inspector.selectMode',
  description: 'Select widget mode',
  icon: FlutterIcons.locate,
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Exit select widget mode',
  disabledTooltip: 'Enter select widget mode',
  gaScreenName: ga.inspector,
  gaItem: ga.selectWidgetMode,
);

/// Toggle whether the inspector on-device overlay is enabled.
///
/// When available, the inspector overlay can be enabled at any time as it will
/// not interfere with user interaction with the app unless inspector select
/// mode is triggered.
final enableOnDeviceInspector = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.inspector.enable',
  description: 'Enable on-device inspector',
  icon: FlutterIcons.locate,
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Exit on-device inspector',
  disabledTooltip: 'Enter on-device inspector',
  gaScreenName: ga.inspector,
  gaItem: ga.enableOnDeviceInspector,
);

final structuredErrors = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.inspector.structuredErrors',
  description: 'Show structured errors',
  icon: FlutterIcons.redError,
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Disable structured errors for Flutter framework issues',
  disabledTooltip: 'Show structured errors for Flutter framework issues',
  gaScreenName: ga.logging,
  gaItem: ga.structuredErrors,
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
];

final Map<String, ServiceExtensionDescription> serviceExtensionsWhitelist =
    Map.fromIterable(
  _extensionDescriptions,
  key: (extension) => extension.extension,
  value: (extension) => extension,
);
