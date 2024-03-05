// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../analytics/analytics.dart' as ga;

double get _tabHeight => scaleByFontFactor(46.0);
double get _textAndIconTabHeight => scaleByFontFactor(72.0);

enum AnalyticsSendSettings {
  sendAll,
  skipForWidgetRebuilds,
  skipAll,
}

class DevToolsTab extends Tab {
  /// Creates a material design [TabBar] tab styled for DevTools.
  ///
  /// The only difference is this tab makes more of an effort to reflect
  /// changes in font and icon sizes.
  DevToolsTab._({
    required Key key,
    String? text,
    Icon? icon,
    EdgeInsets iconMargin = const EdgeInsets.only(bottom: 10.0),
    required this.gaId,
    this.trailing,
    Widget? child,
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
    Key? key,
    required String tabName,
    required String gaPrefix,
    Widget? trailing,
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

  static double calculateHeight(Icon? icon, String? text, Widget? child) {
    return icon == null || (text == null && child == null)
        ? _tabHeight
        : _textAndIconTabHeight;
  }

  /// Tab id for google analytics.
  final String gaId;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: Theme.of(context).textTheme.titleSmall!,
      child: super.build(context),
    );
  }
}

/// A combined [TabBar] and [TabBarView] implementation that tracks tab changes
/// to our analytics.
///
/// When using this widget, ensure that the [AnalyticsTabbedView] is not being
/// rebuilt unnecessarily, as each call to [initState] and [didUpdateWidget]
/// will send an event to analytics for the default selected tab.
class AnalyticsTabbedView extends StatefulWidget {
  AnalyticsTabbedView({
    Key? key,
    this.analyticsSessionIdentifier,
    required this.tabs,
    required this.gaScreen,
    this.sendAnalytics = true,
    this.onTabChanged,
    this.initialSelectedIndex,
  })  : trailingWidgets = List.generate(
          tabs.length,
          (index) => tabs[index].tab.trailing ?? const SizedBox(),
        ),
        super(key: key);

  final List<({DevToolsTab tab, Widget tabView})> tabs;

  final String gaScreen;

  final List<Widget> trailingWidgets;

  final int? initialSelectedIndex;

  /// A value that represents the data object being presented by
  /// [AnalyticsTabbedView].
  ///
  /// This value should represent a unique identifier for the data object being
  /// represented in the view.
  ///
  /// This value ensures that calls to [didUpdateWidget] don't retrigger
  /// analytics events when the data in the view is just being refreshed.
  final String? analyticsSessionIdentifier;

  /// Whether to send analytics events to GA.
  ///
  /// Only set this to false if [AnalyticsTabbedView] is being used for
  /// experimental code we do not want to send GA events for yet.
  final bool sendAnalytics;

  final void Function(int)? onTabChanged;

  @override
  State<AnalyticsTabbedView> createState() => _AnalyticsTabbedViewState();
}

class _AnalyticsTabbedViewState extends State<AnalyticsTabbedView>
    with TickerProviderStateMixin {
  TabController? _tabController;

  int _currentTabControllerIndex = 0;

  void _initTabController({required bool isNewSession}) {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();

    _tabController = TabController(
      length: widget.tabs.length,
      vsync: this,
    );

    final initialIndex = widget.initialSelectedIndex;
    if (initialIndex != null) {
      _currentTabControllerIndex = initialIndex;
    }
    if (_currentTabControllerIndex >= _tabController!.length) {
      _currentTabControllerIndex = 0;
    }
    _tabController!
      ..index = _currentTabControllerIndex
      ..addListener(_onTabChanged);

    // Record a selection for the visible tab, if this is a new session being
    // initialized.
    if (widget.sendAnalytics && isNewSession) {
      ga.select(
        widget.gaScreen,
        widget.tabs[_currentTabControllerIndex].tab.gaId,
        nonInteraction: true,
      );
    }
  }

  void _onTabChanged() {
    final newIndex = _tabController!.index;
    if (_currentTabControllerIndex != newIndex) {
      setState(() {
        _currentTabControllerIndex = newIndex;
        widget.onTabChanged?.call(newIndex);
      });
      if (widget.sendAnalytics) {
        ga.select(
          widget.gaScreen,
          widget.tabs[_currentTabControllerIndex].tab.gaId,
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initTabController(isNewSession: true);
  }

  @override
  void didUpdateWidget(AnalyticsTabbedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs != widget.tabs ||
        oldWidget.gaScreen != widget.gaScreen) {
      final isNewSession = oldWidget.analyticsSessionIdentifier !=
              widget.analyticsSessionIdentifier &&
          widget.analyticsSessionIdentifier != null;
      _initTabController(isNewSession: isNewSession);
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
    final tabBar = OutlineDecoration.onlyBottom(
      child: SizedBox(
        height: defaultHeaderHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: TabBar(
                labelColor: Theme.of(context).textTheme.bodyLarge?.color,
                controller: _tabController,
                tabs: widget.tabs.map((t) => t.tab).toList(),
                isScrollable: true,
              ),
            ),
            widget.trailingWidgets[_currentTabControllerIndex],
          ],
        ),
      ),
    );

    return RoundedOutlinedBorder(
      clip: true,
      child: Column(
        children: [
          tabBar,
          Expanded(
            child: TabBarView(
              physics: defaultTabBarViewPhysics,
              controller: _tabController,
              children: widget.tabs.map((t) => t.tabView).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
