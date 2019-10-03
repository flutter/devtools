// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/diagnostics.dart';

import 'config.dart';
import 'screen.dart';

/// Scaffolding for a screen and navigation in the DevTools App
///
/// This widget will host Screen widgets.
///
/// [Config] defines what screens to show in the app.
/// For a sample implementation, see [ConnectDevToolsScaffold].
class DevToolsScaffold extends StatefulWidget {
  const DevToolsScaffold({
    Key key,
    @required this.tabs,
  })  : assert(tabs != null),
        super(key: key);

  /// A [Key] that indicates the page is showing in narrow-width mode.
  static const Key narrowWidthKey = Key('Narrow Scaffold');

  /// A [Key] that indicates the page is showing in full-width mode.
  static const Key fullWidthKey = Key('Full-width Scaffold');

  /// The width at or below which we treat the screen as narrow-width.
  static const double narrowWidthThreshold = 800.0;

  /// All of the screens that it's possible to navigate to from this Scaffold.
  final List<Screen> tabs;

  @override
  State<StatefulWidget> createState() => DevToolsScaffoldState();
}

class DevToolsScaffoldState extends State<DevToolsScaffold>
    with TickerProviderStateMixin {
  /// A tag used for [Hero] widgets to keep the app title in the same place across page transitions.
  static const String _titleTag = 'App Title';
  TabController _controller;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  @override
  void didUpdateWidget(DevToolsScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabs.length != oldWidget.tabs.length) {
      var newIndex = 0;
      if (_controller != null &&
          widget.tabs.contains(oldWidget.tabs[_controller.index])) {
        newIndex = widget.tabs.indexOf(oldWidget.tabs[_controller.index]);
      }
      _setupController();
      _controller.index = newIndex;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // Sets up the tab controllers.
  void _setupController() {
    _controller?.dispose();
    _controller = TabController(length: widget.tabs.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(),
      body: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: TabBarView(
            controller: _controller,
            children: [for (var screen in widget.tabs) screen.build(context)],
          ),
        ),
      ),
    );
  }

  /// Builds an [AppBar] with the [TabBar] placed on the side or the bottom,
  /// depending on the screen width.
  Widget buildAppBar() {
    const title = Text('Dart DevTools');
    Widget tabs;
    if (widget.tabs.length > 1) {
      tabs = TabBar(
        controller: _controller,
        isScrollable: true,
        tabs: [for (var screen in widget.tabs) screen.buildTab(context)],
      );
    }
    if (MediaQuery.of(context).size.width <=
        DevToolsScaffold.narrowWidthThreshold) {
      return _PreferredSizeHero(
        tag: _titleTag,
        child: AppBar(
          key: DevToolsScaffold.narrowWidthKey,
          automaticallyImplyLeading: false,
          title: title,
          bottom: tabs,
        ),
      );
    }
    return _PreferredSizeHero(
      tag: _titleTag,
      child: AppBar(
        key: DevToolsScaffold.fullWidthKey,
        automaticallyImplyLeading: false,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            title,
            if (tabs != null)
              Padding(
                padding:
                    const EdgeInsets.only(top: 4.0, left: 32.0, right: 32.0),
                child: tabs,
              )
          ],
        ),
      ),
    );
  }
}

class _PreferredSizeHero extends StatelessWidget
    implements PreferredSizeWidget {
  const _PreferredSizeHero({@required this.tag, @required this.child});

  final Object tag;
  final PreferredSizeWidget child;

  @override
  Widget build(BuildContext context) {
    return Hero(tag: tag, child: child);
  }

  @override
  Size get preferredSize => child.preferredSize;
}
