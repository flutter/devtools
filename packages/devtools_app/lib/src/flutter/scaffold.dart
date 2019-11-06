// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'screen.dart';

/// Scaffolding for a screen and navigation in the DevTools App.
///
/// This widget will host Screen widgets.
///
/// [DevToolsApp] defines the collections of [Screen]s to show in a scaffold
/// for different routes.
class DevToolsScaffold extends StatefulWidget {
  const DevToolsScaffold({
    Key key,
    @required this.tabs,
    this.actions,
  })  : assert(tabs != null),
        super(key: key);

  DevToolsScaffold.withChild({Key key, Widget child})
      : this(key: key, tabs: [_SimpleScreen(child)]);

  /// A [Key] that indicates the scaffold is showing in narrow-width mode.
  static const Key narrowWidthKey = Key('Narrow Scaffold');

  /// A [Key] that indicates the scaffold is showing in full-width mode.
  static const Key fullWidthKey = Key('Full-width Scaffold');

  /// The width at or below which we treat the scaffold as narrow-width.
  static const double narrowWidthThreshold = 1000.0;

  /// The size that all actions on this widget are expected to have.
  static const double actionWidgetSize = 48.0;

  /// All of the [Screen]s that it's possible to navigate to from this Scaffold.
  final List<Screen> tabs;

  /// Actions that it's possible to perform in this Scaffold.
  ///
  /// These will generally be [RegisteredServiceExtensionButton]s.
  final List<Widget> actions;

  @override
  State<StatefulWidget> createState() => DevToolsScaffoldState();
}

class DevToolsScaffoldState extends State<DevToolsScaffold>
    with TickerProviderStateMixin {
  /// A tag used for [Hero] widgets to keep the [AppBar] in the same place
  /// across route transitions.
  static const String _appBarTag = 'DevTools AppBar';

  AnimationController appBarAnimation;
  CurvedAnimation appBarCurve;

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

  bool get isNarrow =>
      MediaQuery.of(context).size.width <=
      DevToolsScaffold.narrowWidthThreshold;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // If the animations are null, initialize them.
    appBarAnimation ??= AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: isNarrow ? 1.0 : 0.0,
    );
    appBarCurve ??= CurvedAnimation(
      parent: appBarAnimation,
      curve: Curves.easeInOutCirc,
    );
    if (isNarrow) {
      appBarAnimation.forward();
    } else {
      appBarAnimation.reverse();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    appBarAnimation?.dispose();
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
    return AnimatedBuilder(
      animation: appBarCurve,
      builder: (context, child) {
        return Scaffold(
          appBar: _buildAppBar(),
          body: child,
        );
      },
      child: TabBarView(
        controller: _controller,
        children: tabBodies,
      ),
    );
  }

  /// Builds an [AppBar] with the [TabBar] placed on the side or the bottom,
  /// depending on the screen width.
  Widget _buildAppBar() {
    const title = Text('Dart DevTools');
    Widget flexibleSpace;
    Size preferredSize;
    if (widget.tabs.length > 1) {
      final tabs = TabBar(
        controller: _controller,
        isScrollable: true,
        onTap: _pushScreenToLocalPageRoute,
        tabs: [for (var screen in widget.tabs) screen.buildTab(context)],
      );
      preferredSize = Tween<Size>(
        begin: Size.fromHeight(kToolbarHeight),
        end: Size.fromHeight(kToolbarHeight + tabs.preferredSize.height),
      ).evaluate(appBarCurve);
      final animatedAlignment = Tween<Alignment>(
        begin: Alignment.centerRight,
        end: Alignment.bottomCenter,
      ).evaluate(appBarCurve);
      final animatedRightPadding = Tween<double>(
        begin:
            DevToolsScaffold.actionWidgetSize * (widget.actions?.length ?? 0.0),
        end: 0.0,
      ).evaluate(appBarCurve);
      flexibleSpace = Align(
        alignment: animatedAlignment,
        child: Padding(
          padding: EdgeInsets.only(
            top: 4.0,
            right: animatedRightPadding,
          ),
          child: tabs,
        ),
      );
    }

    final appBar = AppBar(
      // Turn off the appbar's back button on the web.
      automaticallyImplyLeading: !kIsWeb,
      title: title,
      actions: widget.actions,
      flexibleSpace: flexibleSpace,
    );

    if (flexibleSpace == null) return appBar;
    return PreferredSize(
      key: isNarrow
          ? DevToolsScaffold.narrowWidthKey
          : DevToolsScaffold.fullWidthKey,
      preferredSize: preferredSize,
      // Place the AppBar inside of a Hero widget to keep it the same
      // across route transitions.
      child: Hero(
        tag: _appBarTag,
        child: appBar,
      ),
    );
  }
}

class _SimpleScreen extends Screen {
  const _SimpleScreen(this.child) : super('');

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }

  @override
  Widget buildTab(BuildContext context) {
    return null;
  }
}
