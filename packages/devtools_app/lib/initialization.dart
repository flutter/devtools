// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:logging/logging.dart';

import 'src/app.dart';
import 'src/framework/app_error_handling.dart';
import 'src/screens/debugger/syntax_highlighter.dart';
import 'src/screens/provider/riverpod_error_logger_observer.dart';
import 'src/shared/analytics/analytics_controller.dart';
import 'src/shared/config_specific/framework_initialize/framework_initialize.dart';
import 'src/shared/config_specific/logger/logger_helpers.dart';
import 'src/shared/feature_flags.dart';
import 'src/shared/globals.dart';
import 'src/shared/preferences/preferences.dart';
import 'src/shared/primitives/url_utils.dart';
import 'src/shared/primitives/utils.dart';
import 'src/shared/server/server.dart' as server;

final _log = Logger('initializtion');

/// Handles necessary initialization then runs DevTools.
///
/// Any initialization that needs to happen before running DevTools, regardless
/// of context, should happen here.
///
/// If the initialization is specific to running Devtools in google3 or
/// externally, then it should be added to that respective main.dart file.
void runDevTools({
  bool integrationTestMode = false,
  bool shouldEnableExperiments = false,
  List<DevToolsJsonFile> sampleData = const [],
  List<DevToolsScreen>? screens,
}) {
  setupErrorHandling(() async {
    await initializeDevTools(
      integrationTestMode: integrationTestMode,
      shouldEnableExperiments: shouldEnableExperiments,
    );

    // Load the Dart syntax highlighting grammar.
    await SyntaxHighlighter.initialize();

    // Run the app.
    runApp(
      ProviderScope(
        observers: const [ErrorLoggerObserver()],
        child: DevToolsApp(
          screens ?? defaultScreens(sampleData: sampleData),
          await analyticsController,
        ),
      ),
    );
  });
}

@visibleForTesting
Future<void> initializeDevTools({
  bool integrationTestMode = false,
  bool shouldEnableExperiments = false,
}) async {
  initDevToolsLogging();

  // Before switching to URL path strategy, check if this URL is in the legacy
  // fragment format and redirect if necessary.
  if (_handleLegacyUrl()) return;

  usePathUrlStrategy();

  _maybeInitForIntegrationTestMode(
    integrationTestMode: integrationTestMode,
    enableExperiments: shouldEnableExperiments,
  );

  // Initialize the framework before we do anything else, otherwise the
  // StorageController won't be initialized and preferences won't be loaded.
  await initializeFramework();
  await _initDTDConnection();

  final preferences = PreferencesController();
  // Wait for preferences to load before rendering the app to avoid a flash of
  // content with the incorrect theme.
  await preferences.init();

  // This must be called after the DTD connection has been initialized and after
  // preferences have been initialized.
  if (FeatureFlags.devToolsExtensions) {
    await extensionService.initialize();
  }
}

/// Initializes some DevTools global fields for our Flutter integration tests.
///
/// Since we call [runDevTools] from Dart code, we cannot set environment
/// variables before calling [runDevTools], and therefore have to pass in these
/// values manually to [runDevTools].
void _maybeInitForIntegrationTestMode({
  required bool integrationTestMode,
  required bool enableExperiments,
}) {
  if (!integrationTestMode) return;

  setIntegrationTestMode();
  if (enableExperiments) {
    setEnableExperiments();
  }
}

Future<void> _initDTDConnection() async {
  try {
    // Get the dtdUri from the devtools server
    final dtdUri = await server.getDtdUri();

    if (dtdUri != null) {
      await dtdManager.connect(
        dtdUri,
        onError: (e, st) {
          notificationService.pushError(
            'Failed to connect to the Dart Tooling Daemon',
            isReportable: false,
          );
          reportError(
            e,
            errorType: 'Dart Tooling Daemon connection failed.',
            stack: st,
          );
        },
      );
    } else {
      _log.info('No DTD uri provided from the server during initialization.');
    }
  } catch (e, st) {
    // Dtd failing to connect does not interfere with devtools starting up so
    // catch any errors and report them.
    reportError(
      e,
      errorType: 'Failed to initialize the DTD connection.',
      stack: st,
    );
  }
}

/// Checks if the request is for a legacy URL and if so, redirects to the new
/// equivalent.
///
/// Returns `true` if a redirect was performed, in which case normal app
/// initialization should be skipped.
bool _handleLegacyUrl() {
  final url = getWebUrl();
  if (url == null) return false;

  final newUrl = mapLegacyUrl(url);
  if (newUrl != null) {
    webRedirect(newUrl);
    return true;
  }

  return false;
}
