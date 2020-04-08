// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'src/config_specific/flutter/framework_initialize/framework_initialize.dart';
import 'src/flutter/app.dart';
import 'src/flutter/screen.dart';

void main() {
  // TODO(kenz): add some conditional screens.
  const conditionalScreens = <ConditionalScreen>[];

  initializeFramework();

  // Now run the app.
  runApp(
    const DevToolsApp(conditionalScreens),
  );
}
