// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

class ServiceExtension<T> {
  ServiceExtension({
    required this.extension,
    required this.values,
    this.shouldCallOnAllIsolates = false,
  });
  final String extension;

  final List<T> values;

  final bool shouldCallOnAllIsolates;
}

class ToggleableServiceExtension<T> extends ServiceExtension {
  ToggleableServiceExtension({
    required super.extension,
    required T enabledValue,
    required T disabledValue,
    super.shouldCallOnAllIsolates = false,
    this.inverted = false,
  }) : super(values: [enabledValue, disabledValue]);

  static const enabledValueIndex = 0;

  static const disabledValueIndex = 1;

  T get disabledValue => values[disabledValueIndex];

  T get enabledValue => values[enabledValueIndex];

  /// Whether this service extension will be inverted where it is exposed in
  /// DevTools.
  ///
  /// For example, when [inverted] is true, a service extension may have a value
  /// of 'false' in the framework, but will have a perceived value of 'true' in
  /// DevTools, where the language describing the service extension toggle will
  /// also be inverted.
  final bool inverted;
}

final debugAllowBanner = ToggleableServiceExtension<bool>(
  extension:
      '$flutterExtensionPrefix${WidgetsServiceExtensions.debugAllowBanner.name}',
  enabledValue: true,
  disabledValue: false,
);

final debugPaint = ToggleableServiceExtension<bool>(
  extension:
      '$flutterExtensionPrefix${RenderingServiceExtensions.debugPaint.name}',
  enabledValue: true,
  disabledValue: false,
);

final debugPaintBaselines = ToggleableServiceExtension<bool>(
  extension:
      '$flutterExtensionPrefix${RenderingServiceExtensions.debugPaintBaselinesEnabled.name}',
  enabledValue: true,
  disabledValue: false,
);

final disableClipLayers = ToggleableServiceExtension<bool>(
  extension:
      '$flutterExtensionPrefix${RenderingServiceExtensions.debugDisableClipLayers.name}',
  inverted: true,
  enabledValue: true,
  disabledValue: false,
);

final disableOpacityLayers = ToggleableServiceExtension<bool>(
  extension:
      '$flutterExtensionPrefix${RenderingServiceExtensions.debugDisableOpacityLayers.name}',
  inverted: true,
  enabledValue: true,
  disabledValue: false,
);

final disablePhysicalShapeLayers = ToggleableServiceExtension<bool>(
  extension:
      '$flutterExtensionPrefix${RenderingServiceExtensions.debugDisablePhysicalShapeLayers.name}',
  inverted: true,
  enabledValue: true,
  disabledValue: false,
);

/// Toggle whether the inspector on-device overlay is enabled.
///
/// When available, the inspector overlay can be enabled at any time as it will
/// not interfere with user interaction with the app unless inspector select
/// mode is triggered.
final enableOnDeviceInspector = ToggleableServiceExtension<bool>(
  extension: '$inspectorExtensionPrefix.enable',
  enabledValue: true,
  disabledValue: false,
);

final httpEnableTimelineLogging = ToggleableServiceExtension<bool>(
  extension: '${dartIOExtensionPrefix}httpEnableTimelineLogging',
  enabledValue: true,
  disabledValue: false,
  shouldCallOnAllIsolates: true,
);

final invertOversizedImages = ToggleableServiceExtension<bool>(
  extension:
      '$flutterExtensionPrefix${RenderingServiceExtensions.invertOversizedImages.name}',
  enabledValue: true,
  disabledValue: false,
);

final performanceOverlay = ToggleableServiceExtension<bool>(
  extension:
      '$flutterExtensionPrefix${WidgetsServiceExtensions.showPerformanceOverlay.name}',
  enabledValue: true,
  disabledValue: false,
);

final profileRenderObjectLayouts = ToggleableServiceExtension<bool>(
  extension:
      '$flutterExtensionPrefix${RenderingServiceExtensions.profileRenderObjectLayouts.name}',
  enabledValue: true,
  disabledValue: false,
);

final profileRenderObjectPaints = ToggleableServiceExtension<bool>(
  extension:
      '$flutterExtensionPrefix${RenderingServiceExtensions.profileRenderObjectPaints.name}',
  enabledValue: true,
  disabledValue: false,
);

final profileUserWidgetBuilds = ToggleableServiceExtension<bool>(
  extension:
      '$flutterExtensionPrefix${WidgetsServiceExtensions.profileUserWidgetBuilds.name}',
  enabledValue: true,
  disabledValue: false,
);

final profileWidgetBuilds = ToggleableServiceExtension<bool>(
  extension:
      '$flutterExtensionPrefix${WidgetsServiceExtensions.profileWidgetBuilds.name}',
  enabledValue: true,
  disabledValue: false,
);

final repaintRainbow = ToggleableServiceExtension<bool>(
  extension:
      '$flutterExtensionPrefix${RenderingServiceExtensions.repaintRainbow.name}',
  enabledValue: true,
  disabledValue: false,
);

final slowAnimations = ToggleableServiceExtension<num>(
  extension:
      '$flutterExtensionPrefix${SchedulerServiceExtensions.timeDilation.name}',
  enabledValue: 5.0,
  disabledValue: 1.0,
);

final socketProfiling = ToggleableServiceExtension<bool>(
  extension: '${dartIOExtensionPrefix}socketProfilingEnabled',
  enabledValue: true,
  disabledValue: false,
  shouldCallOnAllIsolates: true,
);

final structuredErrors = ToggleableServiceExtension<bool>(
  extension:
      '$inspectorExtensionPrefix.${WidgetInspectorServiceExtensions.structuredErrors.name}',
  enabledValue: true,
  disabledValue: false,
);

// TODO(kenz): remove this if it is not needed. According to the comments,
// [toggleOnDeviceWidgetInspector] should be the legacy extension, but that is
// the only extension available, and [toggleSelectWidgetMode] is not.
// Legacy extension to show the inspector and enable inspector select mode.
final toggleOnDeviceWidgetInspector = ToggleableServiceExtension<bool>(
  extension:
      '$inspectorExtensionPrefix.${WidgetInspectorServiceExtensions.show.name}',
  // Technically this enables the on-device widget inspector but for older
  // versions of package:flutter it makes sense to describe this extension as
  // toggling widget select mode as it is the only way to toggle that mode.
  enabledValue: true,
  disabledValue: false,
);

final togglePlatformMode = ServiceExtension<String>(
  extension:
      '$flutterExtensionPrefix${FoundationServiceExtensions.platformOverride.name}',
  values: ['iOS', 'android', 'fuchsia', 'macOS', 'linux'],
);

/// Toggle whether interacting with the device selects widgets or triggers
/// normal interactions.
final toggleSelectWidgetMode = ToggleableServiceExtension<bool>(
  extension: '$inspectorExtensionPrefix.selectMode',
  enabledValue: true,
  disabledValue: false,
);

final trackRebuildWidgets = ToggleableServiceExtension<bool>(
  extension:
      '$inspectorExtensionPrefix.${WidgetInspectorServiceExtensions.trackRebuildDirtyWidgets.name}',
  enabledValue: true,
  disabledValue: false,
);

final profilePlatformChannels = ToggleableServiceExtension<bool>(
  // TODO(kenz): use ${ServicesServiceExtensions.profilePlatformChannels.name}
  // once this enum value has existed on Flutter stable for a reasonable amount
  // of time (6 months, or June 2024).
  extension: '${flutterExtensionPrefix}profilePlatformChannels',
  enabledValue: true,
  disabledValue: false,
);

// This extensions below should never be displayed as a button so does not need
// a ServiceExtensionDescription object.
final String didSendFirstFrameEvent =
    '$flutterExtensionPrefix${WidgetsServiceExtensions.didSendFirstFrameEvent.name}';

final serviceExtensionsAllowlist = <String, ServiceExtension>{
  for (var extension in _extensionDescriptions) extension.extension: extension,
};

final List<ServiceExtension> _extensionDescriptions = [
  debugAllowBanner,
  debugPaint,
  debugPaintBaselines,
  disableClipLayers,
  disableOpacityLayers,
  disablePhysicalShapeLayers,
  enableOnDeviceInspector,
  httpEnableTimelineLogging,
  invertOversizedImages,
  performanceOverlay,
  profileRenderObjectLayouts,
  profileRenderObjectPaints,
  profileUserWidgetBuilds,
  profileWidgetBuilds,
  repaintRainbow,
  slowAnimations,
  socketProfiling,
  structuredErrors,
  toggleOnDeviceWidgetInspector,
  togglePlatformMode,
  toggleSelectWidgetMode,
  trackRebuildWidgets,
  profilePlatformChannels,
];

/// Service extensions that are not safe to call unless a frame has already
/// been rendered.
///
/// Flutter can sometimes crash if these extensions are called before the first
/// frame is done rendering. We are intentionally conservative about which
/// extensions are safe to run before the first frame as there is little harm
/// in setting these extensions after one frame has rendered without the
/// extension set.
final Set<String> _unsafeBeforeFirstFrameFlutterExtensions = <ServiceExtension>[
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

const dartIOExtensionPrefix = 'ext.dart.io.';
const flutterExtensionPrefix = 'ext.flutter.';
const inspectorExtensionPrefix = 'ext.flutter.inspector';

bool isFlutterExtension(String extensionName) {
  return extensionName.startsWith(flutterExtensionPrefix);
}

bool isDartIoExtension(String extensionName) {
  return extensionName.startsWith(dartIOExtensionPrefix);
}

const hotReloadServiceName = 'reloadSources';
const hotRestartServiceName = 'hotRestart';
