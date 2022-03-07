// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Type of events (event_category):

// ignore_for_file: import_of_legacy_library_into_null_safe

import '../screens/inspector/inspector_screen.dart';
import '../screens/logging/logging_screen.dart';
import '../screens/memory/memory_screen.dart';
import '../screens/network/network_screen.dart';
import '../screens/performance/performance_screen.dart';
import '../screens/profiler/profiler_screen.dart';

const String screenViewEvent = 'screen'; // Active screen (tab selected).
const String selectEvent = 'select'; // User selected something.
const String timingEvent = 'timing'; // Timed operation.

// DevTools GA screenNames:
// These screen ids must match the `screenId` for each respective subclass of
// [Screen]. This is to ensure that the analytics for documentation links match
// the screen id for other analytics on the same screen.
const String inspector = InspectorScreen.id;
const String performance = PerformanceScreen.id;
const String cpuProfiler = ProfilerScreen.id;
const String memory = MemoryScreen.id;
const String network = NetworkScreen.id;
const String logging = LoggingScreen.id;

// GA events not associated with a any screen e.g., hotReload, hotRestart, etc
const String devToolsMain = 'main';
const String hotReload = 'hotReload';
const String hotRestart = 'hotRestart';
const String appDisconnected = 'appDisconnected';

// DevTools UI action selected (clicked).

// Main bar UX actions:
const String feedbackLink = 'feedback';
const String feedbackButton = 'feedbackButton';

// Inspector UX actions:
const String refresh = 'refresh';
const String performanceOverlay = 'performanceOverlay';
const String debugPaint = 'debugPaint';
const String paintBaseline = 'paintBaseline';
const String slowAnimation = 'slowAnimation';
const String repaintRainbow = 'repaintRainbow';
const String debugBanner = 'debugBanner';
const String togglePlatform = 'togglePlatform';
const String selectWidgetMode = 'selectWidgetMode';
const String enableOnDeviceInspector = 'enableOnDeviceInspector';
const String showOnDeviceInspector = 'showInspector';

// Performance UX actions:
const refreshTimelineEvents = 'refreshTimelineEvents';
const timelineFlameChartHelp = 'timelineFlameChartHelp';
const selectFlutterFrame = 'selectFlutterFrame';
const traceEventProcessingTime = 'traceEventProcessingTime';
const String trackRebuilds = 'trackRebuilds';
const String trackPaints = 'trackPaints';
const String trackLayouts = 'trackLayouts';
const disableClipLayersOption = 'disableClipLayers';
const disableOpacityLayersOption = 'disableOpacityLayers';
const disablePhysicalShapeLayersOption = 'disablePhysicalShapeLayers';
const shaderCompilationDocsTooltipLink = 'shaderCompilationDocsTooltipLink';
const analyzeSelectedFrame = 'analyzeSelectedFrame';

// CPU profiler UX actions:
const profileGranularityPrefix = 'profileGranularity';
const loadAllCpuSamples = 'loadAllCpuSamples';
const profileAppStartUp = 'profileAppStartUp';
const cpuProfileFlameChartHelp = 'cpuProfileFlameChartHelp';
const cpuProfileProcessingTime = 'cpuProfileProcessingTime';

// Memory UX actions:
const String gc = 'gc';
const String memoryLegend = 'memoryLegend';
const String memorySettings = 'memorySettings';
const String androidChart = 'androidChart';
const String groupByPrefix = 'groupBy';
const String trackAllocations = 'trackAllocations';
const String resetAllocationAccumulators = 'resetAllocationAccumulators';
const String autoCompleteSearchSelect = 'autoCompleteSearchSelect';
const String takeSnapshot = 'takeSnapshot';
const String snapshotFilterDialog = 'snapshotFilterDialog';
const String sourcesDropDown = 'sourcesDropDown';
const String memoryDisplayInterval = 'chartInterval';
const String treemapToggle = 'treemap';

// Logging UX actions:
const String structuredErrors = 'structuredErrors';
const String trackRebuildWidgets = 'trackRebuildWidgets';

// Landing screen UX actions:
const String landingScreen = 'landing';
const String connectToApp = 'connectToApp';
const String importFile = 'importFile';
const String openAppSizeTool = 'openAppSizeTool';

// Settings actions:
const String settingsDialog = 'settings';
const String darkTheme = 'darkTheme';
const String denseMode = 'denseMode';
const String analytics = 'analytics';
const String vmDeveloperMode = 'vmDeveloperMode';

// Common actions shared across screens.
// These actions will be tracked per screen, so they will still be
// distinguishable from one screen to the other.
const String pause = 'pause';
const String resume = 'resume';
const String clear = 'clear';
const String record = 'record';
const String stop = 'stop';
const String export = 'export';
const String expandAll = 'expandAll';
const String collapseAll = 'collapseAll';
const String documentationLink = 'documentationLink';
// This should track the time from `initState` for a screen to the time when
// the page data has loaded and is ready to interact with.
const String pageReady = 'pageReady';
