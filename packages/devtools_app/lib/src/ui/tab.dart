// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'package:flutter/material.dart';

import '../analytics/analytics.dart' as ga;
import '../shared/theme.dart';
import '../shared/utils.dart';

double get _tabHeight => scaleByFontFactor(46.0);
double get _textAndIconTabHeight => scaleByFontFactor(72.0);

class DevToolsTab extends Tab {
  /// Creates a material design [TabBar] tab styled for DevTools.
  ///
  /// The only difference is this tab makes more of an effort to reflect
  /// changes in font and icon sizes.
  DevToolsTab._({
    Key key,
    String text,
    Icon icon,
    EdgeInsets iconMargin = const EdgeInsets.only(bottom: 10.0),
    this.gaId,
    this.trailing,
    Widget child,
  })  : assert(text != null || child != null || icon != null),
        assert(text == null || child == null),
        super(
          key: key,
          text: text,
          icon: icon,
          iconMargin: iconMargin,
          height: calculateHeight(icon, text, child),
          child: child,
        );

  factory DevToolsTab.create({
    Key key,
    @required String tabName,
    @required String gaPrefix,
    Widget trailing,
  }) {
    return DevToolsTab._(
      key: key ?? ValueKey<String>(tabName),
      gaId: '${gaPrefix}_$tabName',
      trailing: trailing,
      child: Text(
        tabName,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  static double calculateHeight(Icon icon, String text, Widget child) {
    if (icon == null || (text == null && child == null)) {
      return _tabHeight;
    } else {
      return _textAndIconTabHeight;
    }
  }

  /// Tab id for google analytics.
  final String gaId;

  final Widget trailing;
}

/// A combined [TabBar] and [TabBarView] implementation that tracks tab changes
/// to our analytics.
///
/// When using this widget, ensure that the [AnalyticsTabbedView] is not being
/// rebuilt unnecessarily, as each call to [initState] and [didUpdateWidget]
/// will send an event to analytics for the default selected tab.
class AnalyticsTabbedView<T> extends StatefulWidget {
  AnalyticsTabbedView({
    Key key,
    @required this.tabs,
    @required this.tabViews,
    @required this.gaScreen,
    this.tabBarContainer,
    this.tabViewContainer,
  })  : trailingWidgets = List.generate(
          tabs.length,
          (index) => tabs[index].trailing ?? const SizedBox(),
        ),
        super(key: key);

  final List<DevToolsTab> tabs;

  final List<Widget> tabViews;

  final String gaScreen;

  final List<Widget> trailingWidgets;

  final Widget Function(Widget child) tabBarContainer;

  final Widget Function(Widget child) tabViewContainer;

  @override
  _AnalyticsTabbedViewState createState() => _AnalyticsTabbedViewState();
}

class _AnalyticsTabbedViewState extends State<AnalyticsTabbedView>
    with TickerProviderStateMixin {
  TabController _tabController;

  int _currentTabControllerIndex = 0;

  void _initTabController() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();

    _tabController = TabController(
      length: widget.tabs.length,
      vsync: this,
    );
    if (_currentTabControllerIndex >= _tabController.length) {
      _currentTabControllerIndex = 0;
    }
    _tabController
      ..index = _currentTabControllerIndex
      ..addListener(_onTabChanged);

    // Record a selection for the visible tab.
    assert(widget.tabs[_currentTabControllerIndex].gaId != null);
    ga.select(
      widget.gaScreen,
      widget.tabs[_currentTabControllerIndex].gaId,
      nonInteraction: true,
    );
  }

  void _onTabChanged() {
    if (_currentTabControllerIndex != _tabController.index) {
      setState(() {
        _currentTabControllerIndex = _tabController.index;
      });
      assert(widget.tabs[_currentTabControllerIndex].gaId != null);
      ga.select(
        widget.gaScreen,
        widget.tabs[_currentTabControllerIndex].gaId,
        nonInteraction: false,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _initTabController();
  }

  @override
  void didUpdateWidget(AnalyticsTabbedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs != widget.tabs ||
        oldWidget.gaScreen != widget.gaScreen) {
      _initTabController();
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget tabBar = Row(
      children: [
        TabBar(
          labelColor: theme.textTheme.bodyText1.color,
          controller: _tabController,
          tabs: widget.tabs,
          isScrollable: true,
        ),
        Expanded(
          child: widget.trailingWidgets[_currentTabControllerIndex],
        ),
      ],
    );
    if (widget.tabBarContainer != null) {
      tabBar = widget.tabBarContainer(tabBar);
    }

    Widget tabView = TabBarView(
      physics: defaultTabBarViewPhysics,
      controller: _tabController,
      children: widget.tabViews,
    );
    if (widget.tabViewContainer != null) {
      tabView = widget.tabViewContainer(tabView);
    }

    return Column(
      children: [
        tabBar,
        Expanded(
          child: tabView,
        ),
      ],
    );
  }
}
