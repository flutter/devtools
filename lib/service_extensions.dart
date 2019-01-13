// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library service_extensions;

import 'ui/icons.dart';

// Each service extension needs to be added to [_extensionDescriptions].
class ToggleableServiceExtensionDescription<T> {
  const ToggleableServiceExtensionDescription._({
    this.extension,
    this.description,
    this.icon,
    this.enabledValue,
    this.disabledValue,
    String tooltip,
  }) : tooltip = tooltip ?? description;

  final String extension;
  final String description;
  final Icon icon;
  final T enabledValue;
  final T disabledValue;
  final String tooltip;
}

const debugPaint = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.debugPaint',
  description: 'Debug paint',
  tooltip: 'Toggle debug paint',
  icon: FlutterIcons.debugPaint,
  enabledValue: true,
  disabledValue: false,
);

const debugPaintBaselines = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.debugPaintBaselinesEnabled',
  description: 'Paint baselines',
  tooltip: 'Show paint baselines',
  icon: FlutterIcons.painting,
  enabledValue: true,
  disabledValue: false,
);

const repaintRainbow = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.repaintRainbow',
  description: 'Repaint rainbow',
  tooltip: 'Toogle Repaint rainbow',
  icon: FlutterIcons.repaintRainbow,
  enabledValue: true,
  disabledValue: false,
);

const performanceOverlay = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.showPerformanceOverlay',
  description: 'Performance overlay',
  tooltip: 'Toggle performance overlay',
  icon: FlutterIcons.performanceOverlay,
  enabledValue: true,
  disabledValue: false,
);

const debugAllowBanner = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.debugAllowBanner',
  description: 'Hide debug banner',
  tooltip: 'Hide debug mode banner',
  icon: FlutterIcons.debugBanner,
  enabledValue: true,
  disabledValue: false,
);

const profileWidgetBuilds = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.profileWidgetBuilds',
  description: 'Track widget rebuilds',
  tooltip: 'Visualize widget rebuilds',
  icon: FlutterIcons.greyProgr,
  enabledValue: true,
  disabledValue: false,
);

const toggleSelectWidgetMode = ToggleableServiceExtensionDescription<bool>._(
  extension: 'ext.flutter.inspector.show',
  description: 'Toggle Select Mode',
  icon: FlutterIcons.locate,
  enabledValue: true,
  disabledValue: false,
);

const togglePlatformMode = ToggleableServiceExtensionDescription<String>._(
  extension: 'ext.flutter.platformOverride',
  description: 'iOS',
  tooltip: 'Toggle iOS platform',
  icon: FlutterIcons.phone,
  enabledValue: 'iOS',
  disabledValue: 'android',
);

const slowAnimations = ToggleableServiceExtensionDescription<num>._(
  extension: 'ext.flutter.timeDilation',
  description: 'Slow Animations',
  tooltip: 'Toggle slow animations',
  icon: FlutterIcons.history,
  enabledValue: 5.0,
  disabledValue: 1.0,
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
