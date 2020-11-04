// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'analytics/prompt.dart';
import 'analytics/provider.dart';
import 'app.dart';
import 'banner_messages.dart';
import 'common_widgets.dart';
import 'config_specific/drag_and_drop/drag_and_drop.dart';
import 'config_specific/ide_theme/ide_theme.dart';
import 'config_specific/import_export/import_export.dart';
import 'framework_controller.dart';
import 'globals.dart';
import 'notifications.dart';
import 'routing.dart';
import 'screen.dart';
import 'status_line.dart';
import 'theme.dart';

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
    @required this.analyticsProvider,
    this.page,
    this.actions,
    this.embed = false,
    @required this.ideTheme,
  })  : assert(tabs != null),
        super(key: key);

  DevToolsScaffold.withChild({
    Key key,
    @required Widget child,
    @required IdeTheme ideTheme,
    @required AnalyticsProvider analyticsProvider,
    List<Widget> actions,
  }) : this(
          key: key,
          tabs: [SimpleScreen(child)],
          analyticsProvider: analyticsProvider,
          ideTheme: ideTheme,
          actions: actions,
        );

  /// A [Key] that indicates the scaffold is showing in narrow-width mode.
  static const Key narrowWidthKey = Key('Narrow Scaffold');

  /// A [Key] that indicates the scaffold is showing in full-width mode.
  static const Key fullWidthKey = Key('Full-width Scaffold');

  // TODO(jacobr): compute this based on the width of the list of tabs rather
  // than hardcoding. Computing this width dynamically is even more important
  // in the presence of conditional screens.
  /// The width at or below which we treat the scaffold as narrow-width.
  static const double narrowWidthThreshold = 1350.0;

  /// The size that all actions on this widget are expected to have.
  static const double actionWidgetSize = 48.0;

  // Note: when changing this value, also update `flameChartContainerOffset`
  // from flame_chart.dart.
  /// The border around the content in the DevTools UI.
  static const EdgeInsets appPadding =
      EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0);

  /// All of the [Screen]s that it's possible to navigate to from this Scaffold.
  final List<Screen> tabs;

  /// The page being rendered.
  final String page;

  /// Whether to render the embedded view (without the header).
  final bool embed;

  /// IDE-supplied theming.
  final IdeTheme ideTheme;

  /// Actions that it's possible to perform in this Scaffold.
  ///
  /// These will generally be [RegisteredServiceExtensionButton]s.
  final List<Widget> actions;

  final AnalyticsProvider analyticsProvider;

  @override
  State<StatefulWidget> createState() => DevToolsScaffoldState();
}

class DevToolsScaffoldState extends State<DevToolsScaffold>
    with TickerProviderStateMixin {
  /// A tag used for [Hero] widgets to keep the [AppBar] in the same place
  /// across route transitions.
  static const Object _appBarTag = 'DevTools AppBar';

  /// The controller for animating between tabs.
  ///
  /// This will be passed to both the [TabBar] and the [TabBarView] widgets to
  /// coordinate their animation when the tab selection changes.
  TabController _tabController;

  final ValueNotifier<Screen> _currentScreen = ValueNotifier(null);

  ImportController _importController;

  StreamSubscription<ConnectVmEvent> _connectVmSubscription;
  StreamSubscription<String> _showPageSubscription;

  @override
  void initState() {
    super.initState();

    _setupTabController();

    _connectVmSubscription =
        frameworkController.onConnectVmEvent.listen(_connectVm);
    _showPageSubscription =
        frameworkController.onShowPageId.listen(_showPageById);
  }

  @override
  void didUpdateWidget(DevToolsScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.tabs.length != oldWidget.tabs.length) {
      var newIndex = 0;
      // Stay on the current tab if possible when the collection of tabs changes.
      if (_tabController != null &&
          widget.tabs.contains(oldWidget.tabs[_tabController.index])) {
        newIndex = widget.tabs.indexOf(oldWidget.tabs[_tabController.index]);
      }
      // Create a new tab controller to reflect the changed tabs.
      _setupTabController();
      _tabController.index = newIndex;
    } else if (widget.tabs[_tabController.index].screenId != widget.page) {
      // If the page changed (eg. the route was modified by pressing back in the
      // browser), animate to the new one.
      final newIndex = widget.page == null
          ? 0 // When there's no supplied page, we show the first one.
          : widget.tabs.indexWhere((t) => t.screenId == widget.page);
      _tabController.animateTo(newIndex);
    }
  }

  bool get isNarrow =>
      MediaQuery.of(context).size.width <=
      DevToolsScaffold.narrowWidthThreshold;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _importController = ImportController(
      Notifications.of(context),
      _pushSnapshotScreenForImport,
    );
    // This needs to be called at the scaffold level because we need an instance
    // of Notifications above this context.
    surveyService.maybeShowSurveyPrompt(context);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _currentScreen?.dispose();
    _connectVmSubscription?.cancel();
    _showPageSubscription?.cancel();

    super.dispose();
  }

  void _setupTabController() {
    _tabController?.dispose();
    _tabController = TabController(length: widget.tabs.length, vsync: this);

    if (widget.page != null) {
      final initialIndex =
          widget.tabs.indexWhere((screen) => screen.screenId == widget.page);
      if (initialIndex != -1) {
        _tabController.index = initialIndex;
      }
    }

    _currentScreen.value = widget.tabs[_tabController.index];
    _tabController.addListener(() {
      final screen = widget.tabs[_tabController.index];

      if (_currentScreen.value != screen) {
        _currentScreen.value = screen;

        // Send the page change info to the framework controller (it can then
        // send it on to the devtools server, if one is connected).
        frameworkController.notifyPageChange(
          PageChangeEvent(screen?.screenId, widget.embed),
        );

        // If the tab index is 0 and the current route has no page ID (eg. we're
        // at the URL /?uri= with no page ID), those are equivalent pages but
        // navigateIfNotCurrent does not know that and will try to navigate, so
        // skip that here.
        final routerDelegate = DevToolsRouterDelegate.of(context);
        if (_tabController.index == 0 &&
            (routerDelegate.currentConfiguration.page?.isEmpty ?? true)) {
          return;
        }

        // Update routing with the change.
        routerDelegate.navigateIfNotCurrent(screen?.screenId);
      }
    });

    // Broadcast the initial page.
    frameworkController.notifyPageChange(
      PageChangeEvent(_currentScreen.value.screenId, widget.embed),
    );
  }

  /// Connects to the VM with the given URI. This request usually comes from the
  /// IDE via the server API to reuse the DevTools window after being disconnected
  /// (for example if the user stops a debug session then launches a new one).
  void _connectVm(event) {
    DevToolsRouterDelegate.of(context).updateArgsIfNotCurrent({
      'uri': event.serviceProtocolUri.toString(),
      if (event.notify) 'notify': 'true',
    });
  }

  /// Switch to the given page ID. This request usually comes from the server API
  /// for example if the user clicks the Inspector button in the IDE and DevTools
  /// is already open on the Memory page, it should transition to the Inspector page.
  void _showPageById(String pageId) {
    final existingTabIndex = _tabController.index;

    final newIndex =
        widget.tabs.indexWhere((screen) => screen.screenId == pageId);

    if (newIndex != -1 && newIndex != existingTabIndex) {
      DevToolsRouterDelegate.of(context).navigateIfNotCurrent(pageId);
    }
  }

  /// Pushes the snapshot screen for an offline import.
  void _pushSnapshotScreenForImport(String screenId) {
    final args = {'screen': screenId};
    final routerDelegate = DevToolsRouterDelegate.of(context);
    // If we are already in offline mode, we need to replace the existing page
    // so clicking Back does not go through all of the old snapshots.
    if (!offlineMode) {
      enterOfflineMode();
      routerDelegate.navigate(snapshotPageId, args);
    } else {
      // Router.neglect will cause the router to ignore this change, so
      // dragging a new export into the browser will not result in a new
      // history entry.
      Router.neglect(
          context, () => routerDelegate.navigate(snapshotPageId, args));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build the screens for each tab and wrap them in the appropriate styling.
    final tabBodies = [
      for (var screen in widget.tabs)
        Container(
          // TODO(kenz): this padding creates a flash when dragging and dropping
          // into the app size screen because it creates space that is outside
          // of the [DragAndDropEventAbsorber] widget. Fix this.
          padding: DevToolsScaffold.appPadding,
          alignment: Alignment.topLeft,
          child: FocusScope(
            child: AnalyticsPrompt(
              provider: widget.analyticsProvider,
              child: BannerMessages(
                screen: screen,
              ),
            ),
          ),
        ),
    ];

    return ValueListenableProvider.value(
      value: _currentScreen,
      child: Provider<BannerMessagesController>(
        create: (_) => BannerMessagesController(),
        child: DragAndDrop(
          handleDrop: _importController.importData,
          child: Scaffold(
            appBar: widget.embed ? null : _buildAppBar(),
            body: TabBarView(
              physics: defaultTabBarViewPhysics,
              controller: _tabController,
              children: tabBodies,
            ),
            bottomNavigationBar:
                widget.embed ? null : _buildStatusLine(context),
          ),
        ),
      ),
    );
  }

  /// Builds an [AppBar] with the [TabBar] placed on the side or the bottom,
  /// depending on the screen width.
  PreferredSizeWidget _buildAppBar() {
    const title = Text('Dart DevTools');

    Widget flexibleSpace;
    Size preferredSize;
    TabBar tabBar;

    // Add a leading [BulletSpacer] to the actions if the screen is not narrow.
    final actions = List<Widget>.from(widget.actions ?? []);
    if (!isNarrow && actions.isNotEmpty && widget.tabs.length > 1) {
      actions.insert(0, const BulletSpacer(useAccentColor: true));
    }

    if (widget.tabs.length > 1) {
      tabBar = TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: [for (var screen in widget.tabs) screen.buildTab(context)],
      );
      preferredSize = isNarrow
          ? const Size.fromHeight(kToolbarHeight + 40.0)
          : const Size.fromHeight(kToolbarHeight);
      final alignment = isNarrow ? Alignment.bottomLeft : Alignment.centerRight;

      final rightAdjust =
          isNarrow ? 0.0 : DevToolsScaffold.actionWidgetSize / 2;
      final rightPadding = isNarrow
          ? 0.0
          : math.max(
              0.0,
              DevToolsScaffold.actionWidgetSize * (actions?.length ?? 0.0) -
                  rightAdjust);

      flexibleSpace = Align(
        alignment: alignment,
        child: Padding(
          padding: EdgeInsets.only(
            top: 4.0,
            right: rightPadding,
          ),
          child: tabBar,
        ),
      );
    }

    final appBar = AppBar(
      // Turn off the appbar's back button.
      automaticallyImplyLeading: false,
      title: title,
      actions: actions,
      flexibleSpace: flexibleSpace,
    );

    if (flexibleSpace == null) return appBar;

    return PreferredSize(
      key: isNarrow
          ? DevToolsScaffold.narrowWidthKey
          : DevToolsScaffold.fullWidthKey,
      preferredSize: preferredSize,
      // Place the AppBar inside of a Hero widget to keep it the same across
      // route transitions.
      child: Hero(
        tag: _appBarTag,
        child: appBar,
      ),
    );
  }

  Widget _buildStatusLine(BuildContext context) {
    const appPadding = DevToolsScaffold.appPadding;

    return Container(
      height: 48.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PaddedDivider(padding: EdgeInsets.zero),
          Padding(
            padding: EdgeInsets.only(
              left: appPadding.left,
              right: appPadding.right,
              bottom: appPadding.bottom,
            ),
            child: StatusLine(),
          ),
        ],
      ),
    );
  }

  void enterOfflineMode() {
    setState(() {
      offlineMode = true;
    });
  }
}

class SimpleScreen extends Screen {
  const SimpleScreen(this.child) : super(id);

  static const id = 'simple';

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
