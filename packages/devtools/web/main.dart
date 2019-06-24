// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html';
import 'package:devtools/src/framework/framework_core.dart';
import 'package:devtools/src/main.dart';
import 'package:devtools/src/ui/analytics.dart' as ga;
import 'package:devtools/src/ui/analytics_platform.dart' as ga_platform;
import 'package:platform_detect/platform_detect.dart';

void main() {
  // Need to catch all Dart exceptions - done via an isolate.
  runZoned(() {
    // Initialize the core framework.
    FrameworkCore.init();

    // Load the web app framework.
    final PerfToolFramework framework = PerfToolFramework();

    // Show the opt-in dialog for collection analytics?
    try {
      if (ga.isGtagsEnabled() &
          (!window.localStorage.containsKey(ga_platform.devToolsProperty()) ||
              window.localStorage[ga_platform.devToolsProperty()].isEmpty)) {
        framework.showAnalyticsDialog();
      }
    } catch (e) {
      // If there are errors setting up analytics, write them to the console
      // but do not prevent DevTools from loading.
      window.console.error(e);
    }

    if (!browser.isChrome) {
      final browserName =
          // Edge shows up as IE, so we replace it's name to avoid confusion.
          browser.isInternetExplorer || browser == Browser.UnknownBrowser
              ? 'an unsupported browser'
              : browser.name;
      framework.disableAppWithError(
        'ERROR: You are running DevTools on $browserName, '
            'but DevTools only runs on Chrome.',
        'Reopen this url in a Chrome browser to use DevTools.',
      );
      return;
    }

    FrameworkCore.initVmService(errorReporter: (String title, dynamic error) {
      framework.showError(title, error);
    }).then((bool connected) {
      if (!connected) {
        framework.showConnectionDialog();
        framework.showSnapshotMessage();
        // Clear the main element so it stops displaying "Loading..."
        // TODO(jacobr): display a message explaining how to launch a Flutter
        // application from the command line and connect to it with DevTools.
        framework.mainElement.clear();
      }
    });

    framework.loadScreenFromLocation();
  }, onError: (error, stack) {
    // Report exceptions with DevTools to GA, any user's Flutter app exceptions
    // are not collected.
    ga.error('$error\n$stack', true);
    // Also write them to the console to aid debugging (rather than silently
    // failing to load).
    print('$error\n$stack');
  });
}
