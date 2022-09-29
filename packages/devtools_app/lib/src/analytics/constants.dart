// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Type of events (event_category):

import '../screens/inspector/inspector_screen.dart';
import '../screens/logging/logging_screen.dart';
import '../screens/memory/memory_screen.dart';
import '../screens/network/network_screen.dart';
import '../screens/performance/performance_screen.dart';
import '../screens/profiler/profiler_screen.dart';

const screenViewEvent = 'screen'; // Active screen (tab selected).
const selectEvent = 'select'; // User selected something.
const timingEvent = 'timing'; // Timed operation.

// DevTools GA screenNames:
// These screen ids must match the `screenId` for each respective subclass of
// [Screen]. This is to ensure that the analytics for documentation links match
// the screen id for other analytics on the same screen.
const inspector = InspectorScreen.id;
const performance = PerformanceScreen.id;
const cpuProfiler = ProfilerScreen.id;
const memory = MemoryScreen.id;
const network = NetworkScreen.id;
const logging = LoggingScreen.id;

// GA events not associated with a any screen e.g., hotReload, hotRestart, etc
const devToolsMain = 'main';
const hotReload = 'hotReload';
const hotRestart = 'hotRestart';
const appDisconnected = 'appDisconnected';

// DevTools UI action selected (clicked).

// Main bar UX actions:
const feedbackLink = 'feedback';
const feedbackButton = 'feedbackButton';
const discordLink = 'discord';

// Inspector UX actions:
const refresh = 'refresh';
const refreshEmptyTree = 'refreshEmptyTree';
const userRefreshResultsInEmptyTree = 'userRefreshResultsInEmptyTree';
const recomputeTreeRootResultsInEmptyRoot =
    'recomputeTreeRootResultsInEmptyRoot';
const debugPaint = 'debugPaint';
const debugPaintDocs = 'debugPaintDocs';
const paintBaseline = 'paintBaseline';
const paintBaselineDocs = 'paintBaselineDocs';
const slowAnimation = 'slowAnimation';
const slowAnimationDocs = 'slowAnimationDocs';
const repaintRainbow = 'repaintRainbow';
const repaintRainbowDocs = 'repaintRainbowDocs';
const debugBanner = 'debugBanner';
const togglePlatform = 'togglePlatform';
const highlightOversizedImages = 'highlightOversizedImages';
const highlightOversizedImagesDocs = 'highlightOversizedImagesDocs';
const selectWidgetMode = 'selectWidgetMode';
const enableOnDeviceInspector = 'enableOnDeviceInspector';
const showOnDeviceInspector = 'showInspector';
const treeNodeSelection = 'treeNodeSelection';

// Performance UX actions:
const refreshTimelineEvents = 'refreshTimelineEvents';
const performanceOverlay = 'performanceOverlay';
const performanceOverlayDocs = 'performanceOverlayDocs';
const timelineFlameChartHelp = 'timelineFlameChartHelp';
const selectFlutterFrame = 'selectFlutterFrame';
const traceEventProcessingTime = 'traceEventProcessingTime';
const trackRebuilds = 'trackRebuilds';
const trackWidgetBuildsDocs = 'trackWidgetBuildsDocs';
const trackUserCreatedWidgetBuilds = 'trackUserCreatedWidgetBuilds';
const trackPaints = 'trackPaints';
const trackPaintsDocs = 'trackPaintsDocs';
const trackLayouts = 'trackLayouts';
const trackLayoutsDocs = 'trackLayoutsDocs';
const smallEnhanceTracingButton = 'enhanceTracingButtonSmall';
const disableClipLayersOption = 'disableClipLayers';
const disableClipLayersOptionDocs = 'disableClipLayersDocs';
const disableOpacityLayersOption = 'disableOpacityLayers';
const disableOpacityLayersOptionDocs = 'disableOpacityLayersDocs';
const disablePhysicalShapeLayersOption = 'disablePhysicalShapeLayers';
const disablePhysicalShapeLayersOptionDocs = 'disablePhysicalShapeLayersDocs';
const canvasSaveLayerDocs = 'canvasSaveLayerDocs';
const intrinsicOperationsDocs = 'intrinsicOperationsDocs';
const shaderCompilationDocs = 'shaderCompilationDocs';
const shaderCompilationDocsTooltipLink = 'shaderCompilationDocsTooltipLink';
const analyzeSelectedFrame = 'analyzeSelectedFrame';
const collectRasterStats = 'collectRasterStats';

// CPU profiler UX actions:
const profileGranularityPrefix = 'profileGranularity';
const profileGranularityDocs = 'profileGranularityDocs';
const loadAllCpuSamples = 'loadAllCpuSamples';
const profileAppStartUp = 'profileAppStartUp';
const cpuProfileFlameChartHelp = 'cpuProfileFlameChartHelp';
const cpuProfileProcessingTime = 'cpuProfileProcessingTime';

// Memory UX actions:
const gc = 'gc';
const memoryLegend = 'memoryLegend';
const memorySettings = 'memorySettings';
const androidChart = 'androidChart';
const autoSnapshot = 'autoSnapshot';
const showChart = 'showChart';
const hideChart = 'hideChart';
const groupByPrefix = 'groupBy';
const trackAllocations = 'trackAllocations';
const resetAllocationAccumulators = 'resetAllocationAccumulators';
const autoCompleteSearchSelect = 'autoCompleteSearchSelect';
const takeSnapshot = 'takeSnapshot';
const snapshotFilterDialog = 'snapshotFilterDialog';
const sourcesDropDown = 'sourcesDropDown';
const memoryDisplayInterval = 'chartInterval';
const treemapToggle = 'treemap';

// Logging UX actions:
const structuredErrors = 'structuredErrors';
const trackRebuildWidgets = 'trackRebuildWidgets';

// Landing screen UX actions:
const landingScreen = 'landing';
const connectToApp = 'connectToApp';
const importFile = 'importFile';
const openAppSizeTool = 'openAppSizeTool';

// Settings actions:
const settingsDialog = 'settings';
const darkTheme = 'darkTheme';
const denseMode = 'denseMode';
const analytics = 'analytics';
const vmDeveloperMode = 'vmDeveloperMode';
const inspectorHoverEvalMode = 'inspectorHoverEvalMode';

// Object explorer:
const objectInspectorScreen = 'objectInspector';
const programExplorer = 'programExplorer';
const objectStore = 'objectStore';

// Common actions shared across screens.
// These actions will be tracked per screen, so they will still be
// distinguishable from one screen to the other.
const pause = 'pause';
const resume = 'resume';
const clear = 'clear';
const record = 'record';
const stop = 'stop';
const export = 'export';
const expandAll = 'expandAll';
const collapseAll = 'collapseAll';
const profileModeDocs = 'profileModeDocs';
// This should track the time from `initState` for a screen to the time when
// the page data has loaded and is ready to interact with.
const pageReady = 'pageReady';

/// Documentation actions shared across screens.
const documentationLink = 'documentationLink';
String topicDocumentationButton(String topic) => '${topic}DocumentationButton';
String topicDocumentationLink(String topic) => '${topic}DocumentationLink';
