// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library service_extensions;

import 'ui/icons.dart';

class ServiceExtensionDescription<T> {
  const ServiceExtensionDescription({
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

const debugPaint = ServiceExtensionDescription<bool>(
  extension: 'ext.flutter.debugPaint',
  description: 'Debug paint',
  tooltip: 'Toggle debug paint',
  icon: FlutterIcons.debugPaint,
  enabledValue: true,
  disabledValue: false,
);

const debugPaintBaselines = ServiceExtensionDescription<bool>(
  extension: 'ext.flutter.debugPaintBaselinesEnabled',
  description: 'Paint baselines',
  tooltip: 'Show paint baselines',
  icon: FlutterIcons.painting,
  enabledValue: true,
  disabledValue: false,
);

const repaintRainbow = ServiceExtensionDescription<bool>(
  extension: 'ext.flutter.repaintRainbow',
  description: 'Repaint rainbow',
  tooltip: 'Toogle Repaint rainbow',
  icon: FlutterIcons.repaintRainbow,
  enabledValue: true,
  disabledValue: false,
);

const performanceOverlay = ServiceExtensionDescription<bool>(
  extension: 'ext.flutter.showPerformanceOverlay',
  description: 'Performance overlay',
  tooltip: 'Toggle performance overlay',
  icon: FlutterIcons.performanceOverlay,
  enabledValue: true,
  disabledValue: false,
);

const debugAllowBanner = ServiceExtensionDescription<bool>(
  extension: 'ext.flutter.debugAllowBanner',
  description: 'Hide debug banner',
  tooltip: 'Hide debug mode banner',
  icon: FlutterIcons.debugBanner,
  enabledValue: true,
  disabledValue: false,
);

const profileWidgetBuilds = ServiceExtensionDescription<bool>(
  extension: 'ext.flutter.profileWidgetBuilds',
  description: 'Track widget rebuilds',
  tooltip: 'Visualize widget rebuilds',
  icon: FlutterIcons.greyProgress,
  enabledValue: true,
  disabledValue: false,
);

const toggleSelectWidgetMode = ServiceExtensionDescription<bool>(
  extension: 'ext.flutter.inspector.show',
  description: 'Toggle Select Mode',
  icon: FlutterIcons.locate,
  enabledValue: true,
  disabledValue: false,
);

// We do not need to specify enabledValue/disabledValue for this extension.
// [enabledValue] and [disabledValue] depend on the device platform.
const togglePlatformMode = ServiceExtensionDescription<String>(
  extension: 'ext.flutter.platformOverride',
  description: 'Toggle Platform',
  icon: FlutterIcons.phone,
);

const slowAnimations = ServiceExtensionDescription<num>(
  extension: 'ext.flutter.timeDilation',
  description: 'Enable Slow Animations',
  icon: FlutterIcons.history,
  enabledValue: 5.0,
  disabledValue: 1.0,
);

// This extension should never be displayed as a button so does not need a
// ServiceExtensionDescription object.
const String didSendFirstFrameEvent = 'ext.flutter.didSendFirstFrameEvent';
