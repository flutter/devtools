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
import 'theme.dart';

/// Defines a page shown in the DevTools [TabBar].
@immutable
abstract class Screen {
  const Screen(
    this.type, {
    this.title,
    this.icon,
    this.tabKey,
    this.conditionalLibrary,
  });

  final DevToolsScreenType type;

  /// The user-facing name of the page.
  final String title;

  final IconData icon;

  /// An optional key to use when creating the Tab widget (for use during
  /// testing).
  final Key tabKey;

  /// Library uri that determines whether to include this screen in DevTools.
  ///
  /// This can either be a full library uri or it can be a prefix. If null, this
  /// screen will be shown unconditionally.
  ///
  /// Examples:
  ///  * 'package:provider/provider.dart'
  ///  * 'package:provider/'
  final String conditionalLibrary;

  /// Whether this screen should display the isolate selector in the status
  /// line.
  ///
  /// Some screens act on all isolates; for these screens, displaying a
  /// selector doesn't make sense.
  bool get showIsolateSelector => false;

  /// The id to use to synthesize a help URL.
  ///
  /// If the screen does not have a custom documentation page, this property
  /// should return `null`.
  String get docPageId => null;

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
          Icon(icon, size: defaultIconSize),
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

  /// Build a widget to display in the status line.
  ///
  /// If this method returns `null`, then no page specific status is displayed.
  Widget buildStatus(BuildContext context, TextTheme textTheme) {
    return null;
  }
}

class DevToolsScreenType {
  const DevToolsScreenType(this.id, {this.createOverride});

  final String id;

  final Screen Function() createOverride;

  static const inspectorId = 'inspector';
  static const timelineId = 'timeline';
  static const memoryId = 'memory';
  static const performanceId = 'performance';
  static const networkId = 'network';
  static const debuggerId = 'debugger';
  static const loggingId = 'logging';
  static const infoId = 'info';
  static const connectId = 'connect';
  static const simpleId = 'simple';

  static const inspector = DevToolsScreenType(inspectorId);
  static const timeline = DevToolsScreenType(timelineId);
  static const memory = DevToolsScreenType(memoryId);
  static const performance = DevToolsScreenType(performanceId);
  static const network = DevToolsScreenType(networkId);
  static const debugger = DevToolsScreenType(debuggerId);
  static const logging = DevToolsScreenType(loggingId);
  static const info = DevToolsScreenType(infoId);
  static const connect = DevToolsScreenType(connectId);
  static const simple = DevToolsScreenType(simpleId);

  Screen create() {
    switch (id) {
      case inspectorId:
        return const InspectorScreen();
      case timelineId:
        return const TimelineScreen();
      case memoryId:
        return const MemoryScreen();
      case performanceId:
        return const PerformanceScreen();
      case networkId:
        return const NetworkScreen();
      case debuggerId:
        return const DebuggerScreen();
      case loggingId:
        return const LoggingScreen();
      case infoId:
        return const InfoScreen();
      case connectId:
        return const ConnectScreen();
      case simpleId:
        return const SimpleScreen(null);
      default:
        if (createOverride != null) {
          return createOverride();
        }
        return null;
    }
  }
}
