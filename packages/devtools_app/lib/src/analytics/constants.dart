// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Type of events (event_category):

const String screenViewEvent = 'screen'; // Active screen (tab selected).
const String selectEvent = 'select'; // User selected something.

// DevTools GA screenNames:

// GA events not associated with a any screen e.g., hotReload, hotRestart, etc
const String devToolsMain = 'main';
const String inspector = 'inspector';
const String logging = 'logging';
const String performance = 'performance';

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
const String trackRebuilds = 'trackRebuilds';
const String togglePlatform = 'togglePlatform';
const String selectWidgetMode = 'selectWidgetMode';
const String enableOnDeviceInspector = 'enableOnDeviceInspector';
const String showOnDeviceInspector = 'showInspector';

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
const String darkThemeEnable = 'darkTheme-enable';
const String darkThemeDisable = 'darkTheme-disable';
const String denseModeEnable = 'denseMode-enable';
const String denseModeDisable = 'denseMode-disable';
const String analyticsEnable = 'analytics-enable';
const String analyticsDisable = 'analytics-disable';
const String vmDeveloperModeEnable = 'vm-developer-mode-enable';
const String vmDeveloperModeDisable = 'vm-developer-mode-disable';
