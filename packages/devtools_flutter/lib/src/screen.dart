// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// A screen in the DevTools App, including the scaffolding and navigation tabs
/// for navigating the app.
///
/// This widget is used by encapsulation instead of inheritance, so to add a
/// FooScreen to the app, you'll create a FooScreen widget like so:
///
/// ```dart
/// class FooScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return Screen(
///       child: /* Build out the screen content */,
///     )
///   }
/// }
/// ```
///
/// For a sample implementation, see [ConnectScreen].
class Screen extends StatefulWidget {
  const Screen({Key key, @required this.child})
      : assert(child != null),
        super(key: key);

  static const Key narrowWidth = Key('Narrow Screen');
  static const Key fullWidth = Key('Full-width Screen');

  /// The width where we need to treat the screen as narrow-width.
  static const double narrowScreenWidth = 800.0;

  final Widget child;

  @override
  State<StatefulWidget> createState() => ScreenState();
}

class ScreenState extends State<Screen> with TickerProviderStateMixin {
  TabController controller;

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(),
      body: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: widget.child,
        ),
      ),
    );
  }

  /// Builds an [AppBar] with the [TabBar] placed on the side or the bottom,
  /// depending on the screen width.
  Widget buildAppBar() {
    final tabs = TabBar(
      controller: controller,
      isScrollable: true,
      tabs: <Widget>[
        Tab(
          text: 'Flutter Inspector',
          icon: Icon(Icons.map),
        ),
        Tab(
          text: 'Timeline',
          icon: Icon(Icons.timeline),
        ),
        Tab(
          text: 'Performance',
          icon: Icon(Icons.computer),
        ),
        Tab(
          text: 'Memory',
          icon: Icon(Icons.memory),
        ),
        Tab(
          text: 'Logging',
          icon: Icon(Icons.directions_run),
        ),
      ],
    );
    if (MediaQuery.of(context).size.width <= Screen.narrowScreenWidth) {
      return AppBar(
        key: Screen.narrowWidth,
        title: const Text('Dart DevTools'),
        bottom: tabs,
      );
    }
    return AppBar(
      key: Screen.fullWidth,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Dart DevTools'),
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 32.0, right: 32.0),
            child: tabs,
          ),
        ],
      ),
    );
  }
}
