// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'config.dart';
import 'screen.dart';

/// Scaffolding for a screen and navigation in the DevTools App.
///
/// This widget will host Screen widgets.
///
/// [Config] defines the collections of [Screen]s to show in a scaffold
/// for different routes.
class DevToolsScaffold extends StatefulWidget {
  const DevToolsScaffold({
    Key key,
    @required this.tabs,
  })  : assert(tabs != null),
        super(key: key);

  /// A [Key] that indicates the scaffold is showing in narrow-width mode.
  static const Key narrowWidthKey = Key('Narrow Scaffold');

  /// A [Key] that indicates the scaffold is showing in full-width mode.
  static const Key fullWidthKey = Key('Full-width Scaffold');

  /// The width at or below which we treat the scaffold as narrow-width.
  static const double narrowWidthThreshold = 800.0;

  /// All of the [Screen]s that it's possible to navigate to from this Scaffold.
  final List<Screen> tabs;

  @override
  State<StatefulWidget> createState() => DevToolsScaffoldState();
}

class DevToolsScaffoldState extends State<DevToolsScaffold>
    with TickerProviderStateMixin {
  /// A tag used for [Hero] widgets to keep the [AppBar] in the same place
  /// across route transitions.
  static const String _appBarTag = 'DevTools AppBar';

  /// The controller for animating between tabs.
  ///
  /// This will be passed to both the [TabBar] and the [TabBarView] widgets
  /// to coordinate their animation when the tab selection changes.
  TabController _controller;

  @override
  void initState() {
    super.initState();
    _setupTabController();
  }

  @override
  void didUpdateWidget(DevToolsScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabs.length != oldWidget.tabs.length) {
      var newIndex = 0;
      // Stay on the current tab if possible when the collection of tabs changes.
      if (_controller != null &&
          widget.tabs.contains(oldWidget.tabs[_controller.index])) {
        newIndex = widget.tabs.indexOf(oldWidget.tabs[_controller.index]);
      }
      // Create a new tab controller to reflect the changed tabs.
      _setupTabController();
      _controller.index = newIndex;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _setupTabController() {
    _controller?.dispose();
    _controller = TabController(length: widget.tabs.length, vsync: this);
  }

  // Pushes tab changes into the navigation history.
  //
  // Note that this currently works very well, but it doesn't
  // integrate with the browser's history yet.
  void _pushScreenToLocalPageRoute(int newIndex) {
    final previousTabIndex = _controller.previousIndex;
    if (newIndex != previousTabIndex) {
      ModalRoute.of(context).addLocalHistoryEntry(LocalHistoryEntry(
        onRemove: () {
          if (widget.tabs.length >= previousTabIndex) {
            _controller.animateTo(previousTabIndex);
          }
        },
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build the screens for each tab and wrap them in the appropriate styling.
    final tabBodies = [
      for (var screen in widget.tabs)
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: screen.build(context),
          ),
        ),
    ];
    return Scaffold(
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _controller,
        children: tabBodies,
      ),
    );
  }

  /// Builds an [AppBar] with the [TabBar] placed on the side or the bottom,
  /// depending on the screen width.
  Widget _buildAppBar() {
    const title = Text('Dart DevTools');
    Widget tabs;
    if (widget.tabs.length > 1) {
      tabs = TabBar(
        controller: _controller,
        isScrollable: true,
        onTap: _pushScreenToLocalPageRoute,
        tabs: [for (var screen in widget.tabs) screen.buildTab(context)],
      );
    }
    if (MediaQuery.of(context).size.width <=
        DevToolsScaffold.narrowWidthThreshold) {
      return _PreferredSizeHero(
        tag: _appBarTag,
        child: AppBar(
          key: DevToolsScaffold.narrowWidthKey,
          // Turn off the appbar's back button on the web.
          automaticallyImplyLeading: !kIsWeb,
          title: title,
          bottom: tabs,
        ),
      );
    }
    // Place the AppBar inside of a Hero widget to keep it the same
    // across route transitions.
    return _PreferredSizeHero(
      tag: _appBarTag,
      child: AppBar(
        key: DevToolsScaffold.fullWidthKey,
        // Turn off the appbar's back button on the web.
        automaticallyImplyLeading: !kIsWeb,
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
              ),
          ],
        ),
      ),
    );
  }
}

/// Wrapper that places a [PreferredSizeWidget] in a [Hero] such that
/// it can still be passed to fields like [Scaffold.appBar], which
/// requires a [PreferredSizeWidget].
class _PreferredSizeHero extends StatelessWidget
    implements PreferredSizeWidget {
  const _PreferredSizeHero({@required this.tag, @required this.child});

  /// The tag to pass to [Hero.tag] when building the [Hero] widget.
  final Object tag;

  /// The [PreferredSizeWidget] to delegate to for the [preferredSize].
  final PreferredSizeWidget child;

  @override
  Widget build(BuildContext context) {
    return Hero(tag: tag, child: child);
  }

  @override
  Size get preferredSize => child.preferredSize;
}
