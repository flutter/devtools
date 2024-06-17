// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_extensions.dart';

import '../preferences/preferences.dart';
import '../screen.dart';

part 'constants/_cpu_profiler_constants.dart';
part 'constants/_debugger_constants.dart';
part 'constants/_deep_links_constants.dart';
part 'constants/_extension_constants.dart';
part 'constants/_memory_constants.dart';
part 'constants/_logging_constants.dart';
part 'constants/_performance_constants.dart';
part 'constants/_vs_code_sidebar_constants.dart';
part 'constants/_inspector_constants.dart';

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
final deeplink = ScreenMetaData.deepLinks.id;

// GA events not associated with a any screen e.g., hotReload, hotRestart, etc
const devToolsMain = 'main';
const appDisconnected = 'appDisconnected';
const init = 'init';

// DevTools UI action selected (clicked).

// Main bar UX actions:
const hotReload = 'hotReload';
const hotRestart = 'hotRestart';
const importFile = 'importFile';
const feedbackLink = 'feedback';
const feedbackButton = 'feedbackButton';
const contributingLink = 'contributing';
const discordLink = 'discord';
String startingTheme({required bool darkMode}) =>
    'startingTheme-${darkMode ? 'dark' : 'light'}';

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
final defaultDetailsViewToLayoutExplorer =
    InspectorDetailsViewType.layoutExplorer.name;
final defaultDetailsViewToWidgetDetails =
    InspectorDetailsViewType.widgetDetailsTree.name;

enum HomeScreenEvents {
  connectToApp,
  connectToNewApp,
  viewVmFlags,
}

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
const refreshProcessMemoryStatistics = 'refreshProcessMemoryStatistics';
const requestSize = 'requestSize';

// Settings actions:
const settingsDialog = 'settings';
const darkTheme = 'darkTheme';
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
const openFile = 'openFile';
const saveFile = 'saveFile';
const expandAll = 'expandAll';
const collapseAll = 'collapseAll';
const profileModeDocs = 'profileModeDocs';
const visibilityButton = 'visibilityButton';
const stopShowingOfflineData = 'exitOfflineMode';
// This should track the time from `initState` for a screen to the time when
// the page data has loaded and is ready to interact with.
const pageReady = 'pageReady';

/// Documentation actions shared across screens.
const documentationLink = 'documentationLink';
const videoTutorialLink = 'videoTutorialLink';
String topicDocumentationButton(String topic) => '${topic}DocumentationButton';
String topicDocumentationLink(String topic) => '${topic}DocumentationLink';

/// Analytic event constants specific for console.
class ConsoleEvent {
  static const helpInline = 'consoleHelpInline';
  static const evalInStoppedApp = 'consoleEvalInStoppedApp';
  static const evalInRunningApp = 'consoleEvalInRunningApp';
}
