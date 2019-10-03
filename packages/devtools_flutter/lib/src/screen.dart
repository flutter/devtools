// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Defines pages shown in the tabbar of the app.
@immutable
abstract class Screen {
  const Screen(this.name, this.route);

  /// The human-readable name to show for the app.
  final String name;

  /// The route to show in the browser window.
  final String route;

  /// Builds the tab to show for this widget in the app's main navbar.
  ///
  /// This will only be used if this [Screen] is in the app's
  /// [Config.screensWithTabs].
  Widget buildTab(BuildContext context);

  /// Builds the displayed body for this tab.
  Widget build(BuildContext context);
}

/// A placeholder screen that hasn't been implemented.
class EmptyScreen extends Screen {
  const EmptyScreen(String name, String route, this.icon) : super(name, route);

  static const EmptyScreen inspector =
      EmptyScreen('Flutter Inspector', 'inspector', Icons.map);
  static const EmptyScreen timeline =
      EmptyScreen('Timeline', 'timeline', Icons.timeline);
  static const EmptyScreen performance =
      EmptyScreen('Performance', 'performance', Icons.computer);
  static const EmptyScreen memory =
      EmptyScreen('Memory', 'memory', Icons.memory);
  static const EmptyScreen logging =
      EmptyScreen('Logging', 'Logging', Icons.directions_run);

  /// The icon to show for this screen in a tab.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Hello $name',
        style: Theme.of(context).accentTextTheme.headline,
      ),
    );
  }

  @override
  Widget buildTab(BuildContext context) {
    // TODO: implement buildTab
    return Tab(
      text: name,
      icon: Icon(icon),
    );
  }
}
