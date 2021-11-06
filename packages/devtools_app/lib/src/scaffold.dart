// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'analytics/prompt.dart';
import 'app.dart';
import 'auto_dispose_mixin.dart';
import 'banner_messages.dart';
import 'common_widgets.dart';
import 'config_specific/drag_and_drop/drag_and_drop.dart';
import 'config_specific/ide_theme/ide_theme.dart';
import 'config_specific/import_export/import_export.dart';
import 'debugger/console.dart';
import 'debugger/debugger_screen.dart';
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
    Key key,
    @required this.tabs,
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
    List<Widget> actions,
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
  final String page;

  /// Whether to render the embedded view (without the header).
  final bool embed;

  /// IDE-supplied theming.
  final IdeTheme ideTheme;

  /// Actions that it's possible to perform in this Scaffold.
  ///
  /// These will generally be [RegisteredServiceExtensionButton]s.
  final List<Widget> actions;

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
  TabController _tabController;

  Screen _currentScreen;

  ImportController _importController;

  StreamSubscription<ConnectVmEvent> _connectVmSubscription;
  StreamSubscription<String> _showPageSubscription;

  String scaffoldTitle;

  @override
  void initState() {
    super.initState();

    addAutoDisposeListener(offlineController.offlineMode);

    _setupTabController();

    _connectVmSubscription =
        frameworkController.onConnectVmEvent.listen(_connectVm);
    _showPageSubscription =
        frameworkController.onShowPageId.listen(_showPageById);

    _initTitle();
    _maybeShowPubWarning();
  }

  bool _pubWarningShown = false;

  // TODO(kenz): remove the pub warning code after devtools version 2.8.0 ships
  void _maybeShowPubWarning() {
    if (!_pubWarningShown) {
      serviceManager.onConnectionAvailable?.listen((event) {
        if (shouldShowPubWarning()) {
          final colorScheme = Theme.of(context).colorScheme;
          OverlayEntry _entry;
          Overlay.of(context).insert(
            _entry = OverlayEntry(
              maintainState: true,
              builder: (context) {
                return Material(
                  color: colorScheme.overlayShadowColor,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(defaultSpacing),
                      color: colorScheme.overlayBackgroundColor,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const PubWarningText(),
                          const SizedBox(height: defaultSpacing),
                          ElevatedButton(
                            child: const Text('Got it'),
                            onPressed: () => _entry.remove(),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
          _pubWarningShown = true;
        }
      });
    }
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
    _connectVmSubscription?.cancel();
    _showPageSubscription?.cancel();

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
        _tabController.index = initialIndex;
      }
    }

    _currentScreen = widget.tabs[_tabController.index];
    _tabController.addListener(() {
      final screen = widget.tabs[_tabController.index];

      if (_currentScreen != screen) {
        setState(() {
          _currentScreen = screen;
        });

        // Send the page change info to the framework controller (it can then
        // send it on to the devtools server, if one is connected).
        frameworkController.notifyPageChange(
          PageChangeEvent(screen?.screenId, widget.embed),
        );

        // Clear error count when navigating to a screen.
        serviceManager.errorBadgeManager.clearErrors(screen?.screenId);

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
      PageChangeEvent(_currentScreen.screenId, widget.embed),
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
            !serviceManager.connectedApp.isProfileBuildNow &&
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
                  appBar: widget.embed ? null : _buildAppBar(scaffoldTitle),
                  body: (serviceManager.connectedAppInitialized &&
                          !serviceManager.connectedApp.isProfileBuildNow &&
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
                          fractionsKey: 'inspector_console',
                        )
                      : content,
                  bottomNavigationBar: widget.embed ? null : _buildStatusLine(),
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
    Widget flexibleSpace;
    Size preferredSize;
    TabBar tabBar;

    final isNarrow =
        MediaQuery.of(context).size.width <= _wideWidth(title, widget);

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
          ? Size.fromHeight(
              defaultToolbarHeight + scaleByFontFactor(36.0) + 4.0)
          : Size.fromHeight(defaultToolbarHeight);
      final alignment = isNarrow ? Alignment.bottomLeft : Alignment.centerRight;

      final rightAdjust = isNarrow ? 0.0 : BulletSpacer.width;
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

  Widget _buildStatusLine() {
    final appPadding = widget.appPadding;

    return Container(
      height: scaleByFontFactor(24.0) +
          widget.appPadding.top +
          widget.appPadding.bottom,
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
            child: StatusLine(_currentScreen),
          ),
        ],
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

class KeyboardShortcuts extends StatelessWidget {
  const KeyboardShortcuts({
    @required this.keyboardShortcuts,
    @required this.child,
  })  : assert(keyboardShortcuts != null),
        assert(child != null);

  final ShortcutsConfiguration keyboardShortcuts;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (keyboardShortcuts.isEmpty) {
      return child;
    }
    return Shortcuts(
      shortcuts: keyboardShortcuts.shortcuts,
      child: Actions(
        actions: keyboardShortcuts.actions,
        child: child,
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
