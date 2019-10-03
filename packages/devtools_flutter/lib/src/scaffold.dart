// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

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
    @required this.allScreens,
    @required this.screensWithTabs,
  })  : assert(allScreens != null),
        assert(screensWithTabs != null),
        super(key: key);

  /// A [Key] that indicates the page is showing in narrow-width mode.
  static const Key narrowWidthKey = Key('Narrow Scaffold');

  /// A [Key] that indicates the page is showing in full-width mode.
  static const Key fullWidthKey = Key('Full-width Scaffold');

  /// The width at or below which we treat the screen as narrow-width.
  static const double narrowWidthThreshold = 800.0;

  /// All of the screens that it's possible to navigate to from this Scaffold.
  final List<Screen> allScreens;

  /// All screens to create tabs for in this Scaffold.
  ///
  /// [allScreens] must contain all items that are in [screensWithTabs].
  ///
  /// Tabs will be created corresponding to their order in [allScreens].
  final Set<Screen> screensWithTabs;

  @override
  State<StatefulWidget> createState() => DevToolsScaffoldState();
}

class DevToolsScaffoldState extends State<DevToolsScaffold>
    with TickerProviderStateMixin {
  NestedTabController _controller;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  @override
  void didUpdateWidget(DevToolsScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.screensWithTabs.length != oldWidget.screensWithTabs.length ||
        widget.allScreens.length != oldWidget.allScreens.length) {
      _setupController();
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
    final childTabIndices = [
      for (var screen in widget.screensWithTabs)
        widget.allScreens.indexOf(screen)
    ];
    _controller = NestedTabController(
        length: widget.allScreens.length,
        childTabIndices: childTabIndices,
        vsync: this);
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
            children: [
              for (var screen in widget.allScreens) screen.build(context)
            ],
          ),
        ),
      ),
    );
  }

  /// Builds an [AppBar] with the [TabBar] placed on the side or the bottom,
  /// depending on the screen width.
  Widget buildAppBar() {
    final tabs = TabBar(
      controller: _controller.child,
      isScrollable: true,
      tabs: [
        for (var screen in widget.allScreens)
          if (widget.screensWithTabs.contains(screen)) screen.buildTab(context)
      ],
    );
    if (MediaQuery.of(context).size.width <=
        DevToolsScaffold.narrowWidthThreshold) {
      return AppBar(
        key: DevToolsScaffold.narrowWidthKey,
        title: const Text('Dart DevTools'),
        flexibleSpace: tabs,
      );
    }
    return AppBar(
      key: DevToolsScaffold.fullWidthKey,
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

/// Nests tab controllers, so that a child controller can select from a subset of all available tabs.
///
/// In DevTools, we have some screens we want to show in the scaffold that
/// aren't visible in the main tab bar. To show these with animations, we include them in the tab controller.
///
/// This controller exposes a [child], which is a controller limited to only a given subset of tabs.
class NestedTabController extends TabController {
  /// Constructs a [NestedTabController] and [child] with length [length] and child length [childTabIndices].
  NestedTabController({
    @required int length,
    @required List<int> childTabIndices,
    @required TickerProvider vsync,
  })  : assert(length != null && length > 0),
        assert(childTabIndices != null && childTabIndices.isNotEmpty),
        _childTabIndices = childTabIndices,
        child = TabController(
          length: childTabIndices.length,
          vsync: vsync,
        ),
        super(length: length, vsync: vsync) {
    child.addListener(_update);
    addListener(_updateChild);
    _updateChild();
  }

  final TabController child;
  final List<int> _childTabIndices;

  /// Whether or not [child] can show the current [index].
  bool get indexVisibleInChild => _childTabIndices.contains(index);

  /// Matches the child's animations.
  void _update() {
    if (child.indexIsChanging) {
      animateTo(_childTabIndices[child.index]);
    }
  }

  /// Tells the child to match this controller's animation.
  void _updateChild() {
    print(child.index);
    print(index);
    if (indexIsChanging) {
      child.animateTo(_childTabIndices.indexOf(index));
    }
  }

  @override
  void dispose() {
    child.dispose();
    super.dispose();
  }
}
