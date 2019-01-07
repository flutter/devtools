// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library service_extensions;

import 'ui/icons.dart';

class ServiceExtensionDescription {
  const ServiceExtensionDescription({
    this.extension,
    this.description,
    this.icon,
    String tooltip,
  }) : tooltip = tooltip ?? description;

  final String extension;
  final String description;
  final Icon icon;
  final String tooltip;
}

const debugPaint = ServiceExtensionDescription(
  extension: 'ext.flutter.debugPaint',
  description: 'Debug paint',
  tooltip: 'Toggle debug paint',
  icon: FlutterIcons.debugPaint,
);

const debugPaintBaselines = ServiceExtensionDescription(
  extension: 'ext.flutter.debugPaintBaselinesEnabled',
  description: 'Paint baselines',
  tooltip: 'Show paint baselines',
  icon: FlutterIcons.painting,
);

const repaintRainbow = ServiceExtensionDescription(
  extension: 'ext.flutter.repaintRainbow',
  description: 'Repaint rainbow',
  tooltip: 'Toogle Repaint rainbow',
  icon: FlutterIcons.repaintRainbow,
);

const performanceOverlay = ServiceExtensionDescription(
  extension: 'ext.flutter.showPerformanceOverlay',
  description: 'Performance overlay',
  tooltip: 'Toggle performance overlay',
  icon: FlutterIcons.performanceOverlay,
);

const debugAllowBanner = ServiceExtensionDescription(
  extension: 'ext.flutter.debugAllowBanner',
  description: 'Hide debug banner',
  tooltip: 'Hide debug mode banner',
  icon: FlutterIcons.debugBanner,
);

const profileWidgetBuilds = ServiceExtensionDescription(
  extension: 'ext.flutter.profileWidgetBuilds',
  description: 'Track widget rebuilds',
  tooltip: 'Visualize widget rebuilds',
  icon: FlutterIcons.greyProgress,
);

const toggleSelectWidgetMode = ServiceExtensionDescription(
  extension: 'ext.flutter.inspector.show',
  description: 'Toggle Select Mode',
  icon: FlutterIcons.locate,
);

// This extension should never be displayed as a button so does not need a
// ServiceExtensionDescription object.
const String didSendFirstFrameEvent = 'ext.flutter.didSendFirstFrameEvent';
