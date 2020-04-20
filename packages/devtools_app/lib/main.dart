// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'src/config_specific/flutter/framework_initialize/framework_initialize.dart';
import 'src/debugger/flutter/debugger_controller.dart';
import 'src/debugger/flutter/debugger_screen.dart';
// Uncomment to see a sample implementation of a conditional screen.
//import 'src/example/conditional_screen.dart';
import 'src/flutter/app.dart';
import 'src/info/flutter/info_screen.dart';
import 'src/inspector/flutter/inspector_screen.dart';
import 'src/logging/flutter/logging_controller.dart';
import 'src/logging/flutter/logging_screen.dart';
import 'src/memory/flutter/memory_controller.dart';
import 'src/memory/flutter/memory_screen.dart';
import 'src/network/flutter/network_screen.dart';
import 'src/performance/flutter/performance_controller.dart';
import 'src/performance/flutter/performance_screen.dart';
import 'src/timeline/flutter/timeline_controller.dart';
import 'src/timeline/flutter/timeline_screen.dart';

// TODO(bkonyi): remove this bool when page is ready.
const showNetworkPage = false;

void main() {
  /// Screens to initialize DevTools with.
  ///
  /// If the screen depends on a provided controller, the provider should be
  /// provided here.
  ///
  /// Conditional screens can be added to this list, and they will automatically
  /// be shown or hidden based on the [Screen.conditionalLibrary] provided.
  final screens = <DevToolsScreen>[
    const DevToolsScreen(InspectorScreen()),
    DevToolsScreen<TimelineController>(
      const TimelineScreen(),
      createController: () => TimelineController(),
      supportsOffline: true,
    ),
    DevToolsScreen<MemoryController>(
      const MemoryScreen(),
      createController: () => MemoryController(),
    ),
    DevToolsScreen<PerformanceController>(
      const PerformanceScreen(),
      createController: () => PerformanceController(),
    ),
    DevToolsScreen<DebuggerController>(
      const DebuggerScreen(),
      createController: () => DebuggerController(),
    ),
    if (showNetworkPage)
      const DevToolsScreen(NetworkScreen()),
    DevToolsScreen<LoggingController>(
      const LoggingScreen(),
      createController: () => LoggingController(
        onLogCountStatusChanged: (_) {
          // TODO(devoncarew): This callback is not used.
        },
        // TODO(djshuckerow): Use a notifier pattern for the logging controller.
        // That way, it is visible if it has listeners and invisible otherwise.
        isVisible: () => true,
      ),
    ),
    const DevToolsScreen(InfoScreen()),
// Uncomment to see a sample implementation of a conditional screen.
//    DevToolsScreen(
//      screen: const ExampleConditionalScreen(),
//      controllerProvider: (child) => ControllerProvider<ExampleController>(
//        child: child,
//        controller: ExampleController(),
//      ),
//      supportsOffline: true,
//    ),
  ];

  initializeFramework();

  // Now run the app.
  runApp(
    DevToolsApp(screens),
  );
}
