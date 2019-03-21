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

  FrameworkCore.initVmService(errorReporter: (String title, dynamic error) {
    framework.showError(title, error);
  }).then((bool connected) {
    if (!connected) {
      framework.showConnectionDialog();
    }
  });

  if (!browser.isChrome) {
    framework.showWarning('WARNING: Unsupported browser; DevTools is only '
        'supported by Chrome.');
  }

  framework.loadScreenFromLocation();
}
