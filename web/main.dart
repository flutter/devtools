// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools/main.dart';
import 'package:devtools/framework/framework_core.dart';

void main() {
  // Initialize the core framework.
  FrameworkCore.init();

  // Load the web app framework.
  final PerfToolFramework framework = new PerfToolFramework();
  framework.loadScreenFromLocation();
}