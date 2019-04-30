// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library service_extensions;

import 'package:meta/meta.dart';

import 'ui/analytics_constants.dart' as ga;
import 'ui/icons.dart';

// Each service extension needs to be added to [_extensionDescriptions].
class ToggleableServiceExtensionDescription<T> {
  const ToggleableServiceExtensionDescription._({
    this.extension,
    this.description,
    this.icon,
    this.enabledValue,
    this.disabledValue,
    this.enabledTooltip,
    this.disabledTooltip,
    @required this.gaScreenName,
    @required this.gaItem,
  });

  final String extension;
  final String description;
  final Icon icon;
  final T enabledValue;
  final T disabledValue;
  final String enabledTooltip;
  final String disabledTooltip;
  final String gaScreenName; // Analytics screen (screen name where item lives).
  final String gaItem; // Analytics item name (toggleable item's name).
}

const debugAllowBanner = ToggleableServiceExtensionDescription<bool>._(
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

const debugPaint = ToggleableServiceExtensionDescription<bool>._(
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

const debugPaintBaselines = ToggleableServiceExtensionDescription<bool>._(
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

const performanceOverlay = ToggleableServiceExtensionDescription<bool>._(
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

const profileWidgetBuilds = ToggleableServiceExtensionDescription<bool>._(
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

const repaintRainbow = ToggleableServiceExtensionDescription<bool>._(
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

const slowAnimations = ToggleableServiceExtensionDescription<num>._(
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

const togglePlatformMode = ToggleableServiceExtensionDescription<String>._(
  extension: 'ext.flutter.platformOverride',
  description: 'iOS',
  icon: FlutterIcons.phone,
  enabledValue: 'iOS',
  disabledValue: 'android',
  enabledTooltip: 'Toggle iOS Platform',
  disabledTooltip: 'Toggle iOS Platform',
  gaScreenName: ga.inspector,
  gaItem: ga.toggleIoS,
);

const toggleSelectWidgetMode = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.inspector.show',
  description: 'Select Widget Mode',
  icon: FlutterIcons.locate,
  enabledValue: true,
  disabledValue: false,
  enabledTooltip: 'Disable Select Widget Mode',
  disabledTooltip: 'Enable Select Widget Mode',
  gaScreenName: ga.inspector,
  gaItem: ga.selectWidgetMode,
);

// This extension should never be displayed as a button so does not need a
// ServiceExtensionDescription object.
const String didSendFirstFrameEvent = 'ext.flutter.didSendFirstFrameEvent';

const List<ToggleableServiceExtensionDescription> _extensionDescriptions = [
  debugPaint,
  debugPaintBaselines,
  repaintRainbow,
  performanceOverlay,
  debugAllowBanner,
  profileWidgetBuilds,
  toggleSelectWidgetMode,
  togglePlatformMode,
  slowAnimations,
];

final Map<String, ToggleableServiceExtensionDescription>
    toggleableExtensionsWhitelist = Map.fromIterable(
  _extensionDescriptions,
  key: (extension) => extension.extension,
  value: (extension) => extension,
);
