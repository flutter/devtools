// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/material.dart';

import '../../shared/ui/tab.dart';

/// A widget that displays a tabbed view at the bottom of the DevTools screen.
///
/// This widget is used to host views like the console and the AI Assistant.
class BottomPane extends StatelessWidget {
  const BottomPane({super.key, required this.screenId, required this.tabs})
    : assert(tabs.length > 0);

  final String screenId;
  final List<TabbedPane> tabs;

  @override
  Widget build(BuildContext context) {
    return AnalyticsTabbedView(
      gaScreen: screenId,
      tabs: tabs
          .map((tabbedPane) => (tab: tabbedPane.tab, tabView: tabbedPane))
          .toList(),
      staticSingleTab: true,
    );
  }
}

/// An interface for a widget that can be displayed as a tab in a [BottomPane].
abstract class TabbedPane implements Widget {
  /// The tab to display for this pane.
  DevToolsTab get tab;
}
