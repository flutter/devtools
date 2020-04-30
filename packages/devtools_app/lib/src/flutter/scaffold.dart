// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config_specific/flutter/drag_and_drop/drag_and_drop.dart';
import '../config_specific/flutter/import_export/import_export.dart';
import '../globals.dart';
import 'app.dart';
import 'banner_messages.dart';
import 'common_widgets.dart';
import 'notifications.dart';
import 'screen.dart';
import 'snapshot_screen.dart';
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
    this.actions,
  })  : assert(tabs != null),
        super(key: key);

  DevToolsScaffold.withChild({Key key, Widget child})
      : this(key: key, tabs: [SimpleScreen(child)]);

  /// A [Key] that indicates the scaffold is showing in narrow-width mode.
  static const Key narrowWidthKey = Key('Narrow Scaffold');

  /// A [Key] that indicates the scaffold is showing in full-width mode.
  static const Key fullWidthKey = Key('Full-width Scaffold');

  // TODO(jacobr): compute this based on the width of the list of tabs rather
  // than hardcoding. Computing this width dynamically is even more important
  // in the presence of conditional screens.
  /// The width at or below which we treat the scaffold as narrow-width.
  static const double narrowWidthThreshold = 1300.0;

  /// The size that all actions on this widget are expected to have.
  static const double actionWidgetSize = 48.0;

  // Note: when changing this value, also update `flameChartContainerOffset`
  // from flame_chart.dart.
  /// The border around the content in the DevTools UI.
  static const EdgeInsets appPadding =
      EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0);

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
  /// This will be passed to both the [TabBar] and the [TabBarView] widgets to
  /// coordinate their animation when the tab selection changes.
  TabController _tabController;

  final ValueNotifier<Screen> _currentScreen = ValueNotifier(null);

  ImportController _importController;

  StreamSubscription<String> _showPageSubscription;

  @override
  void initState() {
    super.initState();

    _setupTabController();

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

    // If the animations are null, initialize them.
    appBarAnimation ??= defaultAnimationController(
      this,
      value: isNarrow ? 1.0 : 0.0,
    );
    appBarCurve ??= defaultCurvedAnimation(appBarAnimation);
    if (isNarrow) {
      appBarAnimation.forward();
    } else {
      appBarAnimation.reverse();
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _currentScreen?.dispose();
    appBarAnimation?.dispose();
    _showPageSubscription?.cancel();

    super.dispose();
  }

  void _setupTabController() {
    _tabController?.dispose();
    _tabController = TabController(length: widget.tabs.length, vsync: this);

    _currentScreen.value = widget.tabs[_tabController.index];
    _tabController.addListener(() {
      final screen = widget.tabs[_tabController.index];

      if (_currentScreen.value != screen) {
        _currentScreen.value = screen;

        // Send the page change info to the framework controller (it can then
        // send it on to the devtools server, if one is connected).
        frameworkController.notifyPageChange(screen?.screenId);
      }
    });
  }

  /// Switch to the given page ID. This request usually comes from the server API
  /// for example if the user clicks the Inspector button and DevTools is already
  /// open on the Memory page, it should transition to the Inspector page.
  void _showPageById(String pageId) {
    final existingTabIndex = _tabController.index;

    final screen = widget.tabs
        .firstWhere((screen) => screen.screenId == pageId, orElse: () => null);
    final newIndex = screen == null ? -1 : widget.tabs.indexOf(screen);

    if (newIndex != -1 && newIndex != existingTabIndex) {
      _tabController.animateTo(newIndex);
      _pushScreenToLocalPageRoute(newIndex);
    }
  }

  /// Pushes tab changes into the navigation history.
  ///
  /// Note that this currently works very well, but it doesn't integrate with
  /// the browser's history yet.
  void _pushScreenToLocalPageRoute(int newIndex) {
    final previousTabIndex = _tabController.previousIndex;
    if (newIndex != previousTabIndex) {
      ModalRoute.of(context).addLocalHistoryEntry(LocalHistoryEntry(
        onRemove: () {
          if (widget.tabs.length >= previousTabIndex) {
            _tabController.animateTo(previousTabIndex);
          }
        },
      ));
    }
  }

  /// Pushes the snapshot screen for an offline import.
  void _pushSnapshotScreenForImport(String screenId) {
    final args = SnapshotArguments(screenId);
    if (offlineMode) {
      // If we are already in offline mode, only handle routing from existing
      // '/snapshot' route. In this case, we need to first pop the existing
      // '/snapshot' route and push a new one.
      //
      // If we allow other routes that are not the '/snapshot' route to handle
      // routing when we are already offline, the other routes will pop their
      // existing screen ('/connect', or '/') and push '/snapshot' over the top.
      // We want to avoid this because the routes underneath the existing
      // '/snapshot' route should remain unchanged while '/snapshot' sits on
      // top.
      if (ModalRoute.of(context).settings.name == snapshotRoute) {
        Navigator.popAndPushNamed(context, snapshotRoute, arguments: args);
      }
    } else {
      Navigator.pushNamed(context, snapshotRoute, arguments: args);
    }
    setState(() {
      enterOfflineMode();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Build the screens for each tab and wrap them in the appropriate styling.
    final tabBodies = [
      for (var screen in widget.tabs)
        Container(
          padding: DevToolsScaffold.appPadding,
          alignment: Alignment.topLeft,
          child: BannerMessages(
            screen: screen,
          ),
        ),
    ];

    return ValueListenableProvider.value(
      value: _currentScreen,
      child: Provider<BannerMessagesController>(
        create: (_) => BannerMessagesController(),
        child: DragAndDrop(
          // TODO(kenz): we are handling drops from multiple scaffolds. We need
          // to make sure we are only handling drops from the active scaffold.
          handleDrop: _importController.importData,
          child: AnimatedBuilder(
            animation: appBarCurve,
            builder: (context, child) {
              return Scaffold(
                appBar: _buildAppBar(),
                body: child,
                bottomNavigationBar: _buildStatusLine(context),
              );
            },
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _tabController,
              children: tabBodies,
            ),
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
    if (!isNarrow && actions.isNotEmpty) {
      actions.insert(0, const BulletSpacer(useAccentColor: true));
    }

    if (widget.tabs.length > 1) {
      tabBar = TabBar(
        controller: _tabController,
        isScrollable: true,
        onTap: _pushScreenToLocalPageRoute,
        tabs: [for (var screen in widget.tabs) screen.buildTab(context)],
      );
      preferredSize = Tween<Size>(
        begin: const Size.fromHeight(kToolbarHeight),
        end: const Size.fromHeight(kToolbarHeight + 40.0),
      ).evaluate(appBarCurve);
      final animatedAlignment = Tween<Alignment>(
        begin: Alignment.centerRight,
        end: Alignment.bottomLeft,
      ).evaluate(appBarCurve);

      final rightAdjust =
          isNarrow ? 0.0 : DevToolsScaffold.actionWidgetSize / 2;
      final animatedRightPadding = Tween<double>(
        begin: math.max(
            0.0,
            DevToolsScaffold.actionWidgetSize * (actions?.length ?? 0.0) -
                rightAdjust),
        end: 0.0,
      ).evaluate(appBarCurve);

      flexibleSpace = Align(
        alignment: animatedAlignment,
        child: Padding(
          padding: EdgeInsets.only(
            top: 4.0,
            right: animatedRightPadding,
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
