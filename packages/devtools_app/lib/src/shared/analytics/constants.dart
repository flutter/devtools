// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../screen.dart';

part 'constants/_cpu_profiler_constants.dart';
part 'constants/_extension_constants.dart';

// Type of events (event_category):
const screenViewEvent = 'screen'; // Active screen (tab selected).
const selectEvent = 'select'; // User selected something.
const timingEvent = 'timing'; // Timed operation.
const impressionEvent = 'impression'; // Something was viewed.

// DevTools GA screenNames:
// These screen ids must match the `screenId` for each respective subclass of
// [Screen]. This is to ensure that the analytics for documentation links match
// the screen id for other analytics on the same screen.
final home = ScreenMetaData.home.id;
final inspector = ScreenMetaData.inspector.id;
final performance = ScreenMetaData.performance.id;
final cpuProfiler = ScreenMetaData.cpuProfiler.id;
final memory = ScreenMetaData.memory.id;
final network = ScreenMetaData.network.id;
final debugger = ScreenMetaData.debugger.id;
final logging = ScreenMetaData.logging.id;
final appSize = ScreenMetaData.appSize.id;
final vmTools = ScreenMetaData.vmTools.id;
const console = 'console';
final simple = ScreenMetaData.simple.id;

// GA events not associated with a any screen e.g., hotReload, hotRestart, etc
const devToolsMain = 'main';
const appDisconnected = 'appDisconnected';

// DevTools UI action selected (clicked).

// Main bar UX actions:
const hotReload = 'hotReload';
const hotRestart = 'hotRestart';
const importFile = 'importFile';
const feedbackLink = 'feedback';
const feedbackButton = 'feedbackButton';
const contributingLink = 'contributing';
const discordLink = 'discord';

// Inspector UX actions:
const refresh = 'refresh';
const refreshEmptyTree = 'refreshEmptyTree';
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
const inspectorSettings = 'inspectorSettings';
const loggingSettings = 'loggingSettings';
const refreshPubRoots = 'refreshPubRoots';

enum HomeScreenEvents {
  connectToApp,
  connectToNewApp,
  viewVmFlags,
}

enum PerformanceEvents {
  refreshTimelineEvents,
  performanceOverlay,
  timelineFlameChartHelp,
  framesChartVisibility,
  selectFlutterFrame,
  traceEventProcessingTime,
  trackRebuilds,
  trackUserCreatedWidgetBuilds,
  trackPaints,
  trackLayouts,
  enhanceTracingButtonSmall,
  disableClipLayers,
  disableOpacityLayers,
  disablePhysicalShapeLayers,
  collectRasterStats,
  clearRasterStats,
  fullScreenLayerImage,
  clearRebuildStats,
  perfettoModeTraceEventProcessingTime('traceEventProcessingTime-perfettoMode'),
  perfettoLoadTrace,
  perfettoScrollToTimeRange,
  perfettoShowHelp,
  performanceSettings,
  traceCategories;

  const PerformanceEvents([this.nameOverride]);

  final String? nameOverride;
}

enum PerformanceDocs {
  performanceOverlayDocs,
  trackWidgetBuildsDocs,
  trackPaintsDocs,
  trackLayoutsDocs,
  disableClipLayersDocs,
  disableOpacityLayersDocs,
  disablePhysicalShapeLayersDocs,
  canvasSaveLayerDocs,
  intrinsicOperationsDocs,
  shaderCompilationDocs,
  shaderCompilationDocsTooltipLink,
  impellerWikiLink,
}

// Debugger UX actions:
const refreshStatistics = 'refreshStatistics';
const showFileExplorer = 'showFileExplorer';
const hideFileExplorer = 'hideFileExplorer';
const pausedWithNoFrames = 'pausedWithNoFrames';

// Logging UX actions:
const structuredErrors = 'structuredErrors';
const trackRebuildWidgets = 'trackRebuildWidgets';

// App Size Tools UX actions:
const importFileSingle = 'importFileSingle';
const importFileDiffFirst = 'importFileDiffFirst';
const importFileDiffSecond = 'importFileDiffSecond';
const analyzeSingle = 'analyzeSingle';
const analyzeDiff = 'analyzeDiff';

// VM Tools UX Actions:
const refreshIsolateStatistics = 'refreshIsolateStatistics';
const refreshVmStatistics = 'refreshVmStatistics';
const requestSize = 'requestSize';

// Settings actions:
const settingsDialog = 'settings';
const darkTheme = 'darkTheme';
const denseMode = 'denseMode';
const analytics = 'analytics';
const vmDeveloperMode = 'vmDeveloperMode';
const verboseLogging = 'verboseLogging';
const inspectorHoverEvalMode = 'inspectorHoverEvalMode';
const clearLogs = 'clearLogs';
const copyLogs = 'copyLogs';

// Object explorer:
const objectInspectorScreen = 'objectInspector';
const objectInspectorDropDown = 'dropdown';
const programExplorer = 'programExplorer';
const objectStore = 'objectStore';
const classHierarchy = 'classHierarchy';

// Network Events:
const inspectorTreeControllerInitialized = 'InspectorTreeControllerInitialized';
const inspectorTreeControllerRootChange = 'InspectorTreeControllerRootChange';

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
const visibilityButton = 'visibilityButton';
const exitOfflineMode = 'exitOfflineMode';
// This should track the time from `initState` for a screen to the time when
// the page data has loaded and is ready to interact with.
const pageReady = 'pageReady';

/// Documentation actions shared across screens.
const documentationLink = 'documentationLink';
String topicDocumentationButton(String topic) => '${topic}DocumentationButton';
String topicDocumentationLink(String topic) => '${topic}DocumentationLink';

/// Analytic event constants specific for console.
class ConsoleEvent {
  static const helpInline = 'consoleHelpInline';
  static const String evalInStoppedApp = 'consoleEvalInStoppedApp';
  static const String evalInRunningApp = 'consoleEvalInRunningApp';
}

/// Analytic time constants specific for memory screen.
class MemoryTime {
  static const adaptSnapshot = 'adaptSnapshot';
  static const calculateDiff = 'calculateDiff';
  static const updateValues = 'updateValues';
}

// ignore: avoid_classes_with_only_static_members, requires refactor.
/// Analytic event constants specific for memory screen.
class MemoryEvent {
  static const gc = 'gc';
  static const settings = 'settings';

  static const showChartLegend = 'showMemoryLegend';
  static const hideChartLegend = 'hideMemoryLegend';
  static const chartAndroid = 'androidChart';

  static const pauseChart = 'pauseChart';
  static const resumeChart = 'resumeChart';
  static const clearChart = 'clearChart';
  static const showChart = 'showChart';
  static const hideChart = 'hideChart';
  static const chartInterval = 'chartInterval';
  static const chartHelp = 'memoryChartHelp';

  static const leaksAnalyze = 'leaksAnalyze';

  static const profileDownloadCsv = 'profileDownloadCsv';
  static const profileRefreshManual = 'profileRefreshManual';
  static const profileRefreshOnGc = 'profileRefreshOnGc';
  static const profileHelp = 'memoryProfileHelp';

  static const tracingClear = 'tracingClear';
  static const tracingRefresh = 'tracingRefresh';
  static const tracingClassFilter = 'tracingClassFilter';
  static const tracingTraceCheck = 'tracingTraceCheck';
  static const tracingTreeExpandAll = 'tracingTreeExpandAll';
  static const tracingTreeCollapseAll = 'tracingTreeCollapseAll';
  static const tracingHelp = 'memoryTracingHelp';

  static const diffTakeSnapshotControlPane = 'diffTakeSnapshotControlPane';
  static const diffClearSnapshots = 'diffClearSnapshots';
  static const diffHelp = 'memoryDiffHelp';

  static const diffSnapshotDiffSelect = 'diffSnapshotDiffSelect';
  static const diffSnapshotDiffOff = 'diffSnapshotDiffSelectOff';
  static const diffSnapshotFilter = 'diffSnapshotFilter';
  static const diffSnapshotDownloadCsv = 'diffSnapshotDownloadCsv';
  static const diffSnapshotDelete = 'diffSnapshotDelete';

  static const diffClassDiffSelect = 'diffClassDiffSelect';
  static const diffClassSingleSelect = 'diffClassSingleSelect';
  static const diffPathSelect = 'diffPathSelect';
  static const diffClassDiffCopy = 'diffClassDiffCopy';
  static const diffClassSingleCopy = 'diffClassSingleCopy';
  static const diffPathCopy = 'diffPathCopy';
  static const diffPathFilter = 'diffPathFilter';
  static const diffPathInvert = 'diffPathInvert';

  static const diffSnapshotFilterType = 'diffSnapshotFilterType';
  static const diffSnapshotFilterReset = 'diffSnapshotFilterReset';

  static const browseRefLimit = 'browseRefLimit';

  static const dropOneLiveVariable = 'dropOneLiveVariable';
  static const dropOneStaticVariable = 'dropOneStaticVariable';
  static String dropAllLiveToConsole({
    required bool includeSubclasses,
    required bool includeImplementers,
  }) =>
      'dropAllVariables${includeSubclasses ? '_Subclasses' : ''}${includeImplementers ? '_Imlementers' : ''}';
}

/// Areas of memory screen, to prefix event names, when events are emitted
/// by a widget used in different contexts.
enum MemoryAreas {
  profile('profile'),
  snapshotSingle('single'),
  snapshotDiff('diff'),
  snapshotDiffDelta('diff-delta'),
  snapshotDiffNew('diff-new');

  const MemoryAreas(this.name);

  final String name;
}

enum VsCodeFlutterSidebar {
  /// Analytics id to track events that come from the VS Code Flutter sidebar.
  vsCodeFlutterSidebar,

  /// Analytics event that is sent when a device selection occurs from the list
  /// of available devices in the sidebar.
  changeSelectedDevice;

  static String get id => VsCodeFlutterSidebar.vsCodeFlutterSidebar.name;

  /// Analytics event that is sent when a DevTools screen is opened from the
  /// actions toolbar for a debug session.
  static String openDevToolsScreen(String screen) =>
      'openDevToolsScreen-$screen';
}
