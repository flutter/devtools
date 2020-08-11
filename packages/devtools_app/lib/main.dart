// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'src/analytics/stub_provider.dart'
    if (dart.library.html) 'src/analytics/remote_provider.dart';
import 'src/app.dart';
import 'src/config_specific/framework_initialize/framework_initialize.dart';
import 'src/config_specific/ide_theme/ide_theme.dart';
import 'src/config_specific/load_fallback_app/load_fallback_app.dart';
import 'src/preferences.dart';

void main() async {
  final defaultOnError = FlutterError.onError;
  var numErrors = 0;
  var fallbackVersionDialogShown = false;

  // The SKIA/CanvasKit version of Flutter Web is newer than other platforms
  // and depends on WebGL so we need to detect whether it is behaving badly
  // to give users the option to reopen DevTools using a fallback slower version
  // that may be more stable.
  // TODO(jacobr): remove this error listening code once
  // https://github.com/flutter/devtools/issues/2125 is fixed.
  if (const bool.fromEnvironment('FLUTTER_WEB_USE_SKIA')) {
    FlutterError.onError = (FlutterErrorDetails details) {
      if (defaultOnError != null) {
        defaultOnError(details);
      }
      final bool overflowError = details.toString().contains('overflowed');

      if (overflowError) {
        // Overflow errors do not indicate a CanvasKit specific problem and
        // occur frequently in debug builds of apps so we filter them out to
        // avoid distraction. We could alternately suppress this code completely
        // in debug builds but it is risky to add code that runs in release
        // builds but not debug builds.
        return;
      }
      // TODO(jacobr): detect SKIA specific errors and warn on the first SKIA
      // specific error rather than waiting for multiple errors.
      numErrors++;
      if (numErrors >= 20 && !fallbackVersionDialogShown) {
        fallbackVersionDialogShown = true;
        promptToLoadFallbackApp(
          "The Flutter web backend ('CanvasKit') has encountered multiple errors.\n"
          'Would you like to open a fallback version of DevTools that is '
          'slower but does not depend on WebGL?',
        );
      }
    };
  }

  final ideTheme = getIdeTheme();

  final preferences = PreferencesController();
  // Wait for preferences to load before rendering the app to avoid a flash of
  // content with the incorrect theme.
  await preferences.init();

  await initializeFramework();

  // Now run the app.
  runApp(
    DevToolsApp(defaultScreens, preferences, ideTheme, await analyticsProvider),
  );
}
