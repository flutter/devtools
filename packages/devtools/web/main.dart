// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools/src/framework/framework_core.dart';
import 'package:devtools/src/main.dart';

void main() {
  // Initialize the core framework.
  FrameworkCore.init();

  // Load the web app framework.
  final PerfToolFramework framework = PerfToolFramework();

  FrameworkCore.initVmService((String title, dynamic error) {
    framework.showError(title, error);
  });

  framework.loadScreenFromLocation();
}
