// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Defines pages shown in the tabbar of the app.
@immutable
abstract class Screen {
  const Screen(this.name);

  /// The human-readable name to show for the app.
  final String name;

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
  const EmptyScreen(String name, this.icon) : super(name);

  static const EmptyScreen inspector =
      EmptyScreen('Flutter Inspector', Icons.map);
  static const EmptyScreen timeline = EmptyScreen('Timeline', Icons.timeline);
  static const EmptyScreen performance =
      EmptyScreen('Performance', Icons.computer);
  static const EmptyScreen memory = EmptyScreen('Memory', Icons.memory);
  static const EmptyScreen logging =
      EmptyScreen('Logging', Icons.directions_run);

  /// The icon to show for this screen in a tab.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.headline.copyWith(color: theme.accentColor);
    return Center(
      child: Text(
        '$name Page',
        style: style,
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
