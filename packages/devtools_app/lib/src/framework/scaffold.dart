// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../screens/debugger/debugger_screen.dart';
import '../shared/analytics/prompt.dart';
import '../shared/banner_messages.dart';
import '../shared/common_widgets.dart';
import '../shared/config_specific/drag_and_drop/drag_and_drop.dart';
import '../shared/config_specific/ide_theme/ide_theme.dart';
import '../shared/config_specific/import_export/import_export.dart';
import '../shared/console/widgets/console_pane.dart';
import '../shared/framework_controller.dart';
import '../shared/globals.dart';
import '../shared/primitives/auto_dispose.dart';
import '../shared/primitives/simple_items.dart';
import '../shared/primitives/utils.dart';
import '../shared/routing.dart';
import '../shared/screen.dart';
import '../shared/split.dart';
import '../shared/theme.dart';
import '../shared/title.dart';
import '../shared/utils.dart';
import 'about_dialog.dart';
import 'report_feedback_button.dart';
import 'settings_dialog.dart';
import 'status_line.dart';

/// Scaffolding for a screen and navigation in the DevTools App.
///
/// This widget will host Screen widgets.
///
/// [DevToolsApp] defines the collections of [Screen]s to show in a scaffold
/// for different routes.
class DevToolsScaffold extends StatefulWidget {
  DevToolsScaffold({
    Key? key,
    required this.screens,
    this.page,
    List<Widget>? actions,
    this.embed = false,
  })  : actions = actions ?? defaultActions(),
        super(key: key);

  DevToolsScaffold.withChild({
    Key? key,
    required Widget child,
    bool embed = false,
    List<Widget>? actions,
  }) : this(
          key: key,
          screens: [SimpleScreen(child)],
          actions: actions,
          embed: embed,
        );

  /// A [Key] that indicates the scaffold is showing in narrow-width mode.
  static const Key narrowWidthKey = Key('Narrow Scaffold');

  /// A [Key] that indicates the scaffold is showing in full-width mode.
  static const Key fullWidthKey = Key('Full-width Scaffold');

  static List<Widget> defaultActions() => const [
        OpenSettingsAction(),
        ReportFeedbackButton(),
        OpenAboutAction(),
      ];

  /// The padding around the content in the DevTools UI.
  EdgeInsets get appPadding => EdgeInsets.fromLTRB(
        horizontalPadding.left,
        isEmbedded() ? 2.0 : intermediateSpacing,
        horizontalPadding.right,
        isEmbedded() ? 0.0 : intermediateSpacing,
      );

  // Note: when changing this value, also update `flameChartContainerOffset`
  // from flame_chart.dart.
  /// Horizontal padding around the content in the DevTools UI.
  static EdgeInsets get horizontalPadding =>
      EdgeInsets.symmetric(horizontal: isEmbedded() ? 2.0 : 16.0);

  /// All of the [Screen]s that it's possible to navigate to from this Scaffold.
  final List<Screen> screens;

  /// The page being rendered.
  final String? page;

  /// Whether to render the embedded view (without the header).
  final bool embed;

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

    if (widget.screens.length != oldWidget.screens.length) {
      var newIndex = 0;
      // Stay on the current tab if possible when the collection of tabs changes.
      if (_tabController != null &&
          widget.screens.contains(oldWidget.screens[_tabController!.index])) {
        newIndex =
            widget.screens.indexOf(oldWidget.screens[_tabController!.index]);
      }
      // Create a new tab controller to reflect the changed tabs.
      _setupTabController();
      _tabController!.index = newIndex;
    } else if (widget.screens[_tabController!.index].screenId != widget.page) {
      // If the page changed (eg. the route was modified by pressing back in the
      // browser), animate to the new one.
      final newIndex = widget.page == null
          ? 0 // When there's no supplied page, we show the first one.
          : widget.screens.indexWhere((t) => t.screenId == widget.page);
      _tabController!.animateTo(newIndex);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _importController = ImportController(
      _pushSnapshotScreenForImport,
    );
    // This needs to be called at the scaffold level because we need an instance
    // of Notifications above this context.
    surveyService.maybeShowSurveyPrompt();
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
    _tabController = TabController(length: widget.screens.length, vsync: this);

    if (widget.page != null) {
      final initialIndex =
          widget.screens.indexWhere((screen) => screen.screenId == widget.page);
      if (initialIndex != -1) {
        _tabController!.index = initialIndex;
      }
    }

    _currentScreen = widget.screens[_tabController!.index];
    _tabController!.addListener(() {
      final screen = widget.screens[_tabController!.index];

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

        // Update routing with the change.
        final routerDelegate = DevToolsRouterDelegate.of(context);
        routerDelegate.navigateIfNotCurrent(screen.screenId);
      }
    });

    // If we had no explicit page, we want to write one into the URL but
    // without triggering a navigation. Since we can't nagivate during a build
    // we have to wrap this in `Future.microtask`.
    if (widget.page == null && _currentScreen is! SimpleScreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final routerDelegate = DevToolsRouterDelegate.of(context);
        Router.neglect(context, () {
          routerDelegate.navigateIfNotCurrent(
            _currentScreen.screenId,
            routerDelegate.currentConfiguration?.args,
            routerDelegate.currentConfiguration?.state,
          );
        });
      });
    }

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
        widget.screens.indexWhere((screen) => screen.screenId == pageId);

    if (newIndex != -1 && newIndex != existingTabIndex) {
      DevToolsRouterDelegate.of(context).navigateIfNotCurrent(pageId);
    }
  }

  /// Pushes the snapshot screen for an offline import.
  void _pushSnapshotScreenForImport(String screenId) {
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
      for (var screen in widget.screens)
        Align(
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
            child: const FloatingDebuggerControls(),
          ),
      ],
    );
    final theme = Theme.of(context);

    return Provider<BannerMessagesController>(
      create: (_) => BannerMessagesController(),
      child: Provider<ImportController>.value(
        value: _importController,
        builder: (context, _) {
          final showConsole = serviceManager.connectedAppInitialized &&
              !offlineController.offlineMode.value &&
              _currentScreen.showConsole(widget.embed);

          return DragAndDrop(
            handleDrop: _importController.importData,
            child: Title(
              title: scaffoldTitle,
              // Color is a required parameter but the color only appears to
              // matter on Android and we do not care about Android.
              // Using theme.primaryColor matches the default behavior of the
              // title used by [WidgetsApp].
              color: theme.primaryColor.withAlpha(255),
              child: KeyboardShortcuts(
                keyboardShortcuts: _currentScreen.buildKeyboardShortcuts(
                  context,
                ),
                child: Scaffold(
                  appBar: widget.embed
                      ? null
                      :
                      // ignore: avoid-returning-widgets as that would make code more verbose for no clear benefit in this case.
                      _buildAppBar(scaffoldTitle),
                  body: OutlineDecoration.onlyTop(
                    child: Padding(
                      padding: widget.appPadding,
                      child: showConsole
                          ? Split(
                              axis: Axis.vertical,
                              splitters: [
                                ConsolePaneHeader(
                                  backgroundColor: theme.colorScheme.surface,
                                ),
                              ],
                              initialFractions: const [0.8, 0.2],
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: intermediateSpacing,
                                  ),
                                  child: content,
                                ),
                                RoundedOutlinedBorder.onlyBottom(
                                  child: const ConsolePane(),
                                ),
                              ],
                            )
                          : content,
                    ),
                  ),
                  bottomNavigationBar: StatusLine(
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
  PreferredSizeWidget _buildAppBar(String title) {
    Widget? flexibleSpace;
    late final Size preferredSize;
    TabBar tabBar;

    final isNarrow =
        MediaQuery.of(context).size.width <= _wideWidth(title, widget);

    // Add a leading [VerticalLineSpacer] to the actions if the screen is not
    // narrow.
    final actions = List<Widget>.from(widget.actions ?? []);
    if (!isNarrow && actions.isNotEmpty && widget.screens.length > 1) {
      actions.insert(0, VerticalLineSpacer(height: defaultToolbarHeight));
    }

    final bool hasMultipleTabs = widget.screens.length > 1;

    if (hasMultipleTabs) {
      tabBar = TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: [for (var screen in widget.screens) screen.buildTab(context)],
      );
      preferredSize = isNarrow
          ? Size.fromHeight(defaultToolbarHeight * 2 + densePadding)
          : Size.fromHeight(defaultToolbarHeight);
      final alignment = isNarrow ? Alignment.bottomLeft : Alignment.centerRight;

      final rightPadding = isNarrow
          ? 0.0
          : math.max(
              0.0,
              // Use [widget.actions] here instead of [actions] because we may
              // have added a spacer element to [actions] above, which should be
              // excluded from the width calculation.
              actionWidgetSize * ((widget.actions ?? []).length) +
                  (actions.safeFirst is VerticalLineSpacer
                      ? VerticalLineSpacer.totalWidth
                      : 0.0),
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
        style: textTheme.titleLarge,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Approximate size of the title. Add [defaultSpacing] to account for
    // title's leading padding.
    double wideWidth = painter.width + defaultSpacing;
    for (var tab in widget.screens) {
      wideWidth += tab.approximateWidth(textTheme);
    }
    final actionsLength = widget.actions?.length ?? 0;
    if (actionsLength > 0) {
      wideWidth += actionsLength * actionWidgetSize;
    }
    return wideWidth;
  }
}

class KeyboardShortcuts extends StatefulWidget {
  const KeyboardShortcuts({
    super.key,
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
        shortcuts: widget.keyboardShortcuts.shortcuts,
        actions: widget.keyboardShortcuts.actions,
        autofocus: true,
        focusNode: _focusNode,
        child: widget.child,
      ),
    );
  }
}

class SimpleScreen extends Screen {
  SimpleScreen(this.child)
      : super(
          id,
          showFloatingDebuggerControls: false,
        );

  static final id = ScreenMetaData.simple.id;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
