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
  DevToolsTab({
    Key key,
    String text,
    Icon icon,
    EdgeInsets iconMargin = const EdgeInsets.only(bottom: 10.0),
    this.gaId,
    Widget child,
  })  : assert(text != null || child != null || icon != null),
        assert(text == null || child == null),
        super(
            key: key,
            text: text,
            icon: icon,
            iconMargin: iconMargin,
            height: calculateHeight(icon, text, child),
            child: child);

  static double calculateHeight(Icon icon, String text, Widget child) {
    if (icon == null || (text == null && child == null)) {
      return _tabHeight;
    } else {
      return _textAndIconTabHeight;
    }
  }

  /// Tab id for google analytics.
  final String gaId;
}

/// A combined [TabBar] and [TabBarView] implementation that tracks tab changes
/// to our analytics.
///
/// When using this widget, ensure that the [AnalyticsTabbedView] is not being
/// rebuilt unnecessarily, as each call to [initState] and [didUpdateWidget]
/// will send an event to analytics for the default selected tab.
class AnalyticsTabbedView<T> extends StatefulWidget {
  const AnalyticsTabbedView({
    Key key,
    @required this.tabs,
    @required this.tabViews,
    @required this.gaScreen,
  }) : super(key: key);

  final List<DevToolsTab> tabs;

  final List<Widget> tabViews;

  final String gaScreen;

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
    );
  }

  void _onTabChanged() {
    if (_currentTabControllerIndex != _tabController.index) {
      _currentTabControllerIndex = _tabController.index;
      assert(widget.tabs[_currentTabControllerIndex].gaId != null);
      ga.select(
        widget.gaScreen,
        widget.tabs[_currentTabControllerIndex].gaId,
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
    return Column(
      children: [
        Row(
          children: [
            Flexible(
              child: TabBar(
                labelColor: Theme.of(context).textTheme.bodyText1.color,
                controller: _tabController,
                tabs: widget.tabs,
              ),
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            physics: defaultTabBarViewPhysics,
            controller: _tabController,
            children: widget.tabViews,
          ),
        ),
      ],
    );
  }
}
