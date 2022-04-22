// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analytics/prompt.dart';
import '../app.dart';
import '../config_specific/drag_and_drop/drag_and_drop.dart';
import '../config_specific/ide_theme/ide_theme.dart';
import '../config_specific/import_export/import_export.dart';
import '../primitives/auto_dispose_mixin.dart';
import '../screens/debugger/console.dart';
import '../screens/debugger/debugger_screen.dart';
import 'banner_messages.dart';
import 'common_widgets.dart';
import 'framework_controller.dart';
import 'globals.dart';
import 'notifications.dart';
import 'routing.dart';
import 'screen.dart';
import 'split.dart';
import 'status_line.dart';
import 'theme.dart';
import 'title.dart';
import 'utils.dart';

/// Scaffolding for a screen and navigation in the DevTools App.
///
/// This widget will host Screen widgets.
///
/// [DevToolsApp] defines the collections of [Screen]s to show in a scaffold
/// for different routes.
class DevToolsScaffold extends StatefulWidget {
  const DevToolsScaffold({
    Key? key,
    required this.tabs,
    this.page,
    this.actions,
    this.embed = false,
    required this.ideTheme,
  }) : super(key: key);

  DevToolsScaffold.withChild({
    Key? key,
    required Widget child,
    required IdeTheme ideTheme,
    List<Widget>? actions,
  }) : this(
          key: key,
          tabs: [SimpleScreen(child)],
          ideTheme: ideTheme,
          actions: actions,
        );

  /// A [Key] that indicates the scaffold is showing in narrow-width mode.
  static const Key narrowWidthKey = Key('Narrow Scaffold');

  /// A [Key] that indicates the scaffold is showing in full-width mode.
  static const Key fullWidthKey = Key('Full-width Scaffold');

  /// The size that all actions on this widget are expected to have.
  static double get actionWidgetSize => scaleByFontFactor(48.0);

  /// The border around the content in the DevTools UI.
  EdgeInsets get appPadding => EdgeInsets.fromLTRB(
        horizontalPadding.left,
        isEmbedded() ? 2.0 : defaultSpacing,
        horizontalPadding.right,
        isEmbedded() ? 0.0 : denseSpacing,
      );

  // Note: when changing this value, also update `flameChartContainerOffset`
  // from flame_chart.dart.
  /// Horizontal padding around the content in the DevTools UI.
  static EdgeInsets get horizontalPadding =>
      EdgeInsets.symmetric(horizontal: isEmbedded() ? 2.0 : 16.0);

  /// All of the [Screen]s that it's possible to navigate to from this Scaffold.
  final List<Screen> tabs;

  /// The page being rendered.
  final String? page;

  /// Whether to render the embedded view (without the header).
  final bool embed;

  /// IDE-supplied theming.
  final IdeTheme ideTheme;

  /// Actions that it's possible to perform in this Scaffold.
  ///
  /// These will generally be [RegisteredServiceExtensionButton]s.
  final List<Widget>? actions;

  @override
  State<StatefulWidget> createState() => DevToolsScaffoldState();
}

class DevToolsScaffoldState extends State<DevToolsScaffold>
    with AutoDisposeMixin, TickerProviderStateMixin {
  /// A tag used for [Hero] widgets to keep the [AppBar] in the same place
  /// across route transitions.
  static const Object _appBarTag = 'DevTools AppBar';

  /// The controller for animating between tabs.
  ///
  /// This will be passed to both the [TabBar] and the [TabBarView] widgets to
  /// coordinate their animation when the tab selection changes.
  TabController? _tabController;

  late Screen _currentScreen;

  late ImportController _importController;

  late String scaffoldTitle;

  @override
  void initState() {
    super.initState();

    addAutoDisposeListener(offlineController.offlineMode);

    _setupTabController();

    autoDisposeStreamSubscription(
      frameworkController.onShowPageId.listen(_showPageById),
    );

    _initTitle();
  }

  @override
  void didUpdateWidget(DevToolsScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.tabs.length != oldWidget.tabs.length) {
      var newIndex = 0;
      // Stay on the current tab if possible when the collection of tabs changes.
      if (_tabController != null &&
          widget.tabs.contains(oldWidget.tabs[_tabController!.index])) {
        newIndex = widget.tabs.indexOf(oldWidget.tabs[_tabController!.index]);
      }
      // Create a new tab controller to reflect the changed tabs.
      _setupTabController();
      _tabController!.index = newIndex;
    } else if (widget.tabs[_tabController!.index].screenId != widget.page) {
      // If the page changed (eg. the route was modified by pressing back in the
      // browser), animate to the new one.
      final newIndex = widget.page == null
          ? 0 // When there's no supplied page, we show the first one.
          : widget.tabs.indexWhere((t) => t.screenId == widget.page);
      _tabController!.animateTo(newIndex);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _importController = ImportController(
      Notifications.of(context)!,
      _pushSnapshotScreenForImport,
    );
    // This needs to be called at the scaffold level because we need an instance
    // of Notifications above this context.
    surveyService.maybeShowSurveyPrompt(context);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _initTitle() {
    scaffoldTitle = devToolsTitle.value;
    addAutoDisposeListener(devToolsTitle, () {
      setState(() {
        scaffoldTitle = devToolsTitle.value;
      });
    });
  }

  void _setupTabController() {
    _tabController?.dispose();
    _tabController = TabController(length: widget.tabs.length, vsync: this);

    if (widget.page != null) {
      final initialIndex =
          widget.tabs.indexWhere((screen) => screen.screenId == widget.page);
      if (initialIndex != -1) {
        _tabController!.index = initialIndex;
      }
    }

    _currentScreen = widget.tabs[_tabController!.index];
    _tabController!.addListener(() {
      final screen = widget.tabs[_tabController!.index];

      if (_currentScreen != screen) {
        setState(() {
          _currentScreen = screen;
        });

        // Send the page change info to the framework controller (it can then
        // send it on to the devtools server, if one is connected).
        frameworkController.notifyPageChange(
          PageChangeEvent(screen.screenId, widget.embed),
        );

        // Clear error count when navigating to a screen.
        serviceManager.errorBadgeManager.clearErrors(screen.screenId);

        // If the tab index is 0 and the current route has no page ID (eg. we're
        // at the URL /?uri= with no page ID), those are equivalent pages but
        // navigateIfNotCurrent does not know that and will try to navigate, so
        // skip that here.
        final routerDelegate = DevToolsRouterDelegate.of(context);
        if (_tabController!.index == 0 &&
            (routerDelegate.currentConfiguration!.page.isEmpty)) {
          return;
        }

        // Update routing with the change.
        routerDelegate.navigateIfNotCurrent(screen.screenId);
      }
    });

    // Broadcast the initial page.
    frameworkController.notifyPageChange(
      PageChangeEvent(_currentScreen.screenId, widget.embed),
    );
  }

  /// Switch to the given page ID. This request usually comes from the server API
  /// for example if the user clicks the Inspector button in the IDE and DevTools
  /// is already open on the Memory page, it should transition to the Inspector page.
  void _showPageById(String pageId) {
    final existingTabIndex = _tabController!.index;

    final newIndex =
        widget.tabs.indexWhere((screen) => screen.screenId == pageId);

    if (newIndex != -1 && newIndex != existingTabIndex) {
      DevToolsRouterDelegate.of(context).navigateIfNotCurrent(pageId);
    }
  }

  /// Pushes the snapshot screen for an offline import.
  void _pushSnapshotScreenForImport(String screenId) {
    // TODO(kenz): for 'performance' imports, load the legacy screen or the new
    // screen based on the flutter version of the imported file.
    final args = {'screen': screenId};
    final routerDelegate = DevToolsRouterDelegate.of(context);
    if (!offlineController.offlineMode.value) {
      routerDelegate.navigate(snapshotPageId, args);
    } else {
      // If we are already in offline mode, we need to replace the existing page
      // so clicking Back does not go through all of the old snapshots.
      // Router.neglect will cause the router to ignore this change, so
      // dragging a new export into the browser will not result in a new
      // history entry.
      Router.neglect(
        context,
        () => routerDelegate.navigate(snapshotPageId, args),
      );
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
          padding: widget.appPadding,
          alignment: Alignment.topLeft,
          child: FocusScope(
            child: AnalyticsPrompt(
              child: BannerMessages(
                screen: screen,
              ),
            ),
          ),
        ),
    ];

    final content = Stack(
      children: [
        TabBarView(
          physics: defaultTabBarViewPhysics,
          controller: _tabController,
          children: tabBodies,
        ),
        if (serviceManager.connectedAppInitialized &&
            !serviceManager.connectedApp!.isProfileBuildNow! &&
            !offlineController.offlineMode.value &&
            _currentScreen.showFloatingDebuggerControls)
          Container(
            alignment: Alignment.topCenter,
            child: FloatingDebuggerControls(),
          ),
      ],
    );
    final theme = Theme.of(context);

    return Provider<BannerMessagesController>(
      create: (_) => BannerMessagesController(),
      child: Provider<ImportController>.value(
        value: _importController,
        builder: (context, _) {
          return DragAndDrop(
            handleDrop: _importController.importData,
            child: Title(
              title: scaffoldTitle,
              // Color is a required parameter but the color only appears to
              // matter on Android and we do not care about Android.
              // Using theme.primaryColor matches the default behavior of the
              // title used by [WidgetsApp].
              color: theme.primaryColor,
              child: KeyboardShortcuts(
                keyboardShortcuts: _currentScreen.buildKeyboardShortcuts(
                  context,
                ),
                child: Scaffold(
                  appBar: widget.embed
                      ? null
                      : _buildAppBar(scaffoldTitle) as PreferredSizeWidget?,
                  body: (serviceManager.connectedAppInitialized &&
                          !serviceManager.connectedApp!.isProfileBuildNow! &&
                          !offlineController.offlineMode.value &&
                          _currentScreen.showConsole(widget.embed))
                      ? Split(
                          axis: Axis.vertical,
                          children: [
                            content,
                            Padding(
                              padding: DevToolsScaffold.horizontalPadding,
                              child: const DebuggerConsole(),
                            ),
                          ],
                          splitters: [
                            DebuggerConsole.buildHeader(),
                          ],
                          initialFractions: const [0.8, 0.2],
                        )
                      : content,
                  bottomNavigationBar: DevToolsFooter(
                    appPadding: widget.appPadding,
                    currentScreen: _currentScreen,
                    isEmbedded: widget.embed,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds an [AppBar] with the [TabBar] placed on the side or the bottom,
  /// depending on the screen width.
  Widget _buildAppBar(String title) {
    Widget? flexibleSpace;
    late final Size preferredSize;
    TabBar tabBar;

    final isNarrow =
        MediaQuery.of(context).size.width <= _wideWidth(title, widget);

    // Add a leading [BulletSpacer] to the actions if the screen is not narrow.
    final actions = List<Widget>.from(widget.actions ?? []);
    if (!isNarrow && actions.isNotEmpty && widget.tabs.length > 1) {
      actions.insert(0, const BulletSpacer(useAccentColor: true));
    }

    final bool hasMultipleTabs = widget.tabs.length > 1;

    if (hasMultipleTabs) {
      tabBar = TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: [for (var screen in widget.tabs) screen.buildTab(context)],
      );
      preferredSize = isNarrow
          ? Size.fromHeight(
              defaultToolbarHeight + scaleByFontFactor(36.0) + 4.0,
            )
          : Size.fromHeight(defaultToolbarHeight);
      final alignment = isNarrow ? Alignment.bottomLeft : Alignment.centerRight;

      final rightAdjust = isNarrow ? 0.0 : BulletSpacer.width;
      final rightPadding = isNarrow
          ? 0.0
          : math.max(
              0.0,
              DevToolsScaffold.actionWidgetSize * (actions.length) -
                  rightAdjust,
            );

      flexibleSpace = Align(
        alignment: alignment,
        child: Padding(
          padding: EdgeInsets.only(
            top: isNarrow ? scaleByFontFactor(36.0) + 4.0 : 4.0,
            right: rightPadding,
          ),
          child: tabBar,
        ),
      );
    }

    final appBar = AppBar(
      // Turn off the appbar's back button.
      automaticallyImplyLeading: false,
      title: Text(
        title,
        style: Theme.of(context).devToolsTitleStyle,
      ),
      centerTitle: false,
      toolbarHeight: defaultToolbarHeight,
      actions: actions,
      flexibleSpace: flexibleSpace,
    );

    if (!hasMultipleTabs) return appBar;

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

  /// Returns the width of the scaffold title, tabs and default icons.
  double _wideWidth(String title, DevToolsScaffold widget) {
    final textTheme = Theme.of(context).textTheme;
    final painter = TextPainter(
      text: TextSpan(
        text: title,
        style: textTheme.headline6,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Approximate size of the title. Add [defaultSpacing] to account for
    // title's leading padding.
    double wideWidth = painter.width + defaultSpacing;
    for (var tab in widget.tabs) {
      wideWidth += tab.approximateWidth(textTheme);
    }
    final actionsLength = widget.actions?.length ?? 0;
    if (actionsLength > 0) {
      wideWidth += actionsLength * DevToolsScaffold.actionWidgetSize +
          BulletSpacer.width;
    }
    return wideWidth;
  }
}

class DevToolsFooter extends StatelessWidget {
  const DevToolsFooter({
    Key? key,
    required this.appPadding,
    required this.currentScreen,
    required this.isEmbedded,
  }) : super(key: key);

  final EdgeInsets appPadding;
  final Screen currentScreen;
  final bool isEmbedded;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: scaleByFontFactor(24.0) + appPadding.top + appPadding.bottom,
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
            child: StatusLine(
              currentScreen,
              isEmbedded,
            ),
          ),
        ],
      ),
    );
  }
}

class KeyboardShortcuts extends StatefulWidget {
  const KeyboardShortcuts({
    required this.keyboardShortcuts,
    required this.child,
  });

  final ShortcutsConfiguration keyboardShortcuts;
  final Widget child;

  @override
  KeyboardShortcutsState createState() => KeyboardShortcutsState();
}

class KeyboardShortcutsState extends State<KeyboardShortcuts>
    with AutoDisposeMixin {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'keyboard-shortcuts');
    autoDisposeFocusNode(_focusNode);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.keyboardShortcuts.isEmpty) {
      return widget.child;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).requestFocus(_focusNode),
      child: FocusableActionDetector(
        child: widget.child,
        shortcuts: widget.keyboardShortcuts.shortcuts,
        actions: widget.keyboardShortcuts.actions,
        autofocus: true,
        focusNode: _focusNode,
      ),
    );
  }
}

class SimpleScreen extends Screen {
  const SimpleScreen(this.child)
      : super(
          id,
          showFloatingDebuggerControls: false,
        );

  static const id = 'simple';

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
