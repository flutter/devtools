// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/extension_points/extensions_base.dart';
import 'src/extension_points/extensions_external.dart';
import 'src/framework/app_error_handling.dart';
import 'src/screens/debugger/syntax_highlighter.dart';
import 'src/screens/provider/riverpod_error_logger_observer.dart';
import 'src/shared/analytics/analytics_controller.dart';
import 'src/shared/config_specific/framework_initialize/framework_initialize.dart';
import 'src/shared/config_specific/ide_theme/ide_theme.dart';
import 'src/shared/config_specific/url/url.dart';
import 'src/shared/config_specific/url_strategy/url_strategy.dart';
import 'src/shared/feature_flags.dart';
import 'src/shared/globals.dart';
import 'src/shared/preferences.dart';
import 'src/shared/primitives/url_utils.dart';

void main() async {
  await runDevTools(runApp);
}

Future<void> runDevTools(
  FutureOr<void> Function(Widget) runner, {
  bool useCustomErrorHandling = true,
  bool shouldEnableExperiments = false,
}) async {
  // Before switching to URL path strategy, check if this URL is in the legacy
  // fragment format and redirect if necessary.
  if (_handleLegacyUrl()) return;

  // If we don't comment this out, we can't run the integration tests. See
  // see https://github.com/flutter/flutter/issues/116936. However, if we comment
  // this out, then we can only run once test per file, because the second test
  // case will hit line 37 and redirect and return early.
  usePathUrlStrategy();

  // This may be from our Flutter integration tests. Since we call
  // [runDevTools] from Dart code, we cannot set the 'enable_experiements'
  // environment variable before calling [runDevTools].
  if (shouldEnableExperiments) {
    setEnableExperiments();
  }

  // Initialize the framework before we do anything else, otherwise the
  // StorageController won't be initialized and preferences won't be loaded.
  await initializeFramework();

  setGlobal(IdeTheme, getIdeTheme());

  // Set the extension points global.
  setGlobal(DevToolsExtensionPoints, ExternalDevToolsExtensionPoints());

  final preferences = PreferencesController();
  // Wait for preferences to load before rendering the app to avoid a flash of
  // content with the incorrect theme.
  await preferences.init();

  // Load the Dart syntax highlighting grammar.
  await SyntaxHighlighter.initialize();

  FutureOr<void> runCallback() async => await runner(
        MaterialApp(home: Text('this is my app')),
      );

  // FutureOr<void> runCallback() async => await runner(
  //       ProviderScope(
  //         observers: const [ErrorLoggerObserver()],
  //         child: DevToolsApp(defaultScreens, await analyticsController),
  //       ),
  //     );

  if (useCustomErrorHandling) {
    setupErrorHandling(() async {
      // Run the app.
      await runCallback();
    });
  } else {
    await runCallback();
  }
}

/// Checks if the request is for a legacy URL and if so, redirects to the new
/// equivalent.
///
/// Returns `true` if a redirect was performed, in which case normal app
/// initialization should be skipped.
bool _handleLegacyUrl() {
  final url = getWebUrl();
  print('in _handleLegacyUrl: $url');
  if (url == null) return false;

  final newUrl = mapLegacyUrl(url);
  if (newUrl != null) {
    print('performing redirect to $newUrl');
    webRedirect(newUrl);
    return true;
  }

  return false;
}
