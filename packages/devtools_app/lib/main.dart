// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'src/config_specific/flutter/framework_initialize/framework_initialize.dart';
import 'src/debugger/flutter/debugger_screen.dart';
import 'src/flutter/app.dart';
import 'src/flutter/screen.dart';
import 'src/info/flutter/info_screen.dart';
import 'src/inspector/flutter/inspector_screen.dart';
import 'src/logging/flutter/logging_screen.dart';
import 'src/memory/flutter/memory_screen.dart';
import 'src/network/flutter/network_screen.dart';
import 'src/performance/flutter/performance_screen.dart';
import 'src/timeline/flutter/timeline_screen.dart';

// TODO(bkonyi): remove this bool when page is ready.
const showNetworkPage = false;

void main() {
  // Conditional screens can be added to this list, and they will automatically
  // be shown or hidden based on the [conditionalLibrary] provided.
  const screens = <Screen>[
    InspectorScreen(),
    TimelineScreen(),
    MemoryScreen(),
    PerformanceScreen(),
    DebuggerScreen(),
    if (showNetworkPage) NetworkScreen(),
    LoggingScreen(),
    InfoScreen(),
  ];

  initializeFramework();

  // Now run the app.
  runApp(
    const DevToolsApp(screens),
  );
}
