// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Type of events (event_category):
const String applicationEvent = 'application'; // visible/hidden
const String screenViewEvent = 'screen'; // Active screen (tab selected).
const String selectEvent = 'select'; // User selected something.

const String errorError = 'onerror'; // Browser onError detected in DevTools
const String exceptionEvent = 'exception'; // Any Dart exception in DevTools

// DevTools GA screenNames:

// GA events not associated with a any screen e.g., hotReload, hotRestart, etc
const String devToolsMain = 'main';
const String debugger = 'debugger';
const String inspector = 'inspector';
const String logging = 'logging';
const String memory = 'memory';
const String performance = 'performance';
const String timeline = 'timeline';

// DevTools UI action selected (clicked).

// Main bar UX actions:
const String hotReload = 'hotReload';
const String hotRestart = 'hotRestart';
const String feedback = 'feedback';

// Common UX actions:
const String pause = 'pause'; // Memory, Timeline, Debugger
const String resume = 'resume'; // Memory, Timeline, Debugger

// Inspector UX actions:
const String widgetMode = 'widgetMode';
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

// Timeline UX actions:
const String timelineFrame = 'frame'; // Frame selected in frame chart
const String timelineFlameRaster = 'flameRaster'; // Selected a Raster flame
const String timelineFlameUi = 'flameUI'; // Selected a UI flame

// Memory UX actions:
const String search = 'search';
const String snapshot = 'snapshot';
const String reset = 'reset';
const String gC = 'gc';
const String inspectClass = 'inspectClass'; // inspect a class from snapshot
const String inspectInstance = 'inspectInstance'; // inspect an instance
const String inspectData = 'inspectData'; // inspect data of the instance

// Debugger UX actions:
const String openShortcut = 'openShortcut';
const String stepIn = 'stepIn';
const String stepOver = 'stepOver';
const String stepOut = 'stepOut';
const String bP = 'bp';
const String unhandledExceptions = 'unhandledExceptions';
const String allExceptions = 'allExceptions';

// Logging UX actions:
const String clearLogs = 'clearLogs';
const String structuredErrors = 'structuredErrors';
