// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../debugger/flutter/debugger_screen.dart';
import '../info/flutter/info_screen.dart';
import '../inspector/flutter/inspector_screen.dart';
import '../logging/flutter/logging_screen.dart';
import '../memory/flutter/memory_screen.dart';
import '../network/flutter/network_screen.dart';
import '../performance/flutter/performance_screen.dart';
import '../timeline/flutter/timeline_screen.dart';
import 'connect_screen.dart';
import 'scaffold.dart';

/// Defines pages shown in the tabbar of the app.
@immutable
abstract class Screen {
  const Screen(this.type, {this.title, this.icon, this.tabKey});

  final DevToolsScreenType type;

  /// The user-facing name of the page.
  final String title;

  final IconData icon;

  /// An optional key to use when creating the Tab widget (for use during
  /// testing).
  final Key tabKey;

  /// Builds the tab to show for this screen in the [DevToolsScaffold]'s main
  /// navbar.
  ///
  /// This will not be used if the [Screen] is the only one shown in the
  /// scaffold.
  Widget buildTab(BuildContext context) {
    return Tab(
      key: tabKey,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16.0),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(title),
          ),
        ],
      ),
    );
  }

  /// Builds the body to display for this tab.
  Widget build(BuildContext context);
}

enum DevToolsScreenType {
  inspector,
  timeline,
  memory,
  performance,
  logging,
  info,
  connect,
  debugger,
  network,
  simple,
}

extension DevToolsScreenTypeExtension on DevToolsScreenType {
  Screen create() {
    switch (this) {
      case DevToolsScreenType.inspector:
        return const InspectorScreen();
      case DevToolsScreenType.timeline:
        return const TimelineScreen();
      case DevToolsScreenType.memory:
        return const MemoryScreen();
      case DevToolsScreenType.performance:
        return const PerformanceScreen();
      case DevToolsScreenType.logging:
        return const LoggingScreen();
      case DevToolsScreenType.info:
        return const InfoScreen();
      case DevToolsScreenType.connect:
        return const ConnectScreen();
      case DevToolsScreenType.debugger:
        return const DebuggerScreen();
      case DevToolsScreenType.network:
        return const NetworkScreen();
      case DevToolsScreenType.simple:
        return const SimpleScreen(null);
      default:
        return null;
    }
  }
}
