// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Type of events (event_category):

import '../inspector/inspector_screen.dart';
import '../logging/logging_screen.dart';
import '../performance/performance_screen.dart';

const String screenViewEvent = 'screen'; // Active screen (tab selected).
const String selectEvent = 'select'; // User selected something.

// DevTools GA screenNames:

// These screen ids must match the `screenId` for each respective subclass of
// [Screen]. This is to ensure that the analytics for documentation links match
// the screen id for other analytics on the same screen.
const String inspector = InspectorScreen.id;
const String performance = PerformanceScreen.id;
const String logging = LoggingScreen.id;

// GA events not associated with a any screen e.g., hotReload, hotRestart, etc
const String devToolsMain = 'main';

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
const String darkTheme = 'darkTheme';
const String denseMode = 'denseMode';
const String analytics = 'analytics';
const String vmDeveloperMode = 'vm-developer-mode';

const String documentationLink = 'documentationLink';
