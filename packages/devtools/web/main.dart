// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools/src/framework/framework_core.dart';
import 'package:devtools/src/main.dart';
import 'package:platform_detect/platform_detect.dart';

void main() {
  // Initialize the core framework.
  FrameworkCore.init();

  // Load the web app framework.
  final PerfToolFramework framework = PerfToolFramework();

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
    }
  });

  framework.loadScreenFromLocation();
}
