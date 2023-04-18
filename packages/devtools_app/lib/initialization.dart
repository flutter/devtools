// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/framework/app_error_handling.dart';
import 'src/screens/debugger/syntax_highlighter.dart';
import 'src/screens/provider/riverpod_error_logger_observer.dart';
import 'src/shared/analytics/analytics_controller.dart';
import 'src/shared/config_specific/framework_initialize/framework_initialize.dart';
import 'src/shared/config_specific/ide_theme/ide_theme.dart';
import 'src/shared/config_specific/logger/logger_helpers.dart';
import 'src/shared/config_specific/url/url.dart';
import 'src/shared/config_specific/url_strategy/url_strategy.dart';
import 'src/shared/feature_flags.dart';
import 'src/shared/globals.dart';
import 'src/shared/preferences.dart';
import 'src/shared/primitives/url_utils.dart';
import 'src/shared/primitives/utils.dart';

/// Handles necessary initialization then runs DevTools.
///
/// Any initialization that needs to happen before running DevTools, regardless
/// of context, should happen here.
///
/// If the initialization is specific to running Devtools in google3 or
/// externally, then it should be added to that respective main.dart file.
void runDevTools({
  bool shouldEnableExperiments = false,
  List<DevToolsJsonFile> sampleData = const [],
  List<DevToolsScreen>? screens,
}) {
  setupErrorHandling(() async {
    screens ??= defaultScreens;

    initDevToolsLogging();

    // Before switching to URL path strategy, check if this URL is in the legacy
    // fragment format and redirect if necessary.
    if (_handleLegacyUrl()) return;

    usePathUrlStrategy();

    // This may be set to true from our Flutter integration tests. Since we call
    // [runDevTools] from Dart code, we cannot set the 'enable_experiments'
    // environment variable before calling [runDevTools].
    if (shouldEnableExperiments) {
      setEnableExperiments();
    }

    // Initialize the framework before we do anything else, otherwise the
    // StorageController won't be initialized and preferences won't be loaded.
    await initializeFramework();

    setGlobal(IdeTheme, getIdeTheme());

    final preferences = PreferencesController();
    // Wait for preferences to load before rendering the app to avoid a flash of
    // content with the incorrect theme.
    await preferences.init();

    // Load the Dart syntax highlighting grammar.
    await SyntaxHighlighter.initialize();

    // Run the app.
    runApp(
      ProviderScope(
        observers: const [ErrorLoggerObserver()],
        child: DevToolsApp(
          screens!,
          await analyticsController,
          sampleData: sampleData,
        ),
      ),
    );
  });
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
