// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pedantic/pedantic.dart';
import 'package:provider/provider.dart';

import '../devtools.dart' as devtools;
import 'analytics/analytics_stub.dart'
    if (dart.library.html) 'analytics/analytics.dart' as ga;
import 'analytics/constants.dart';
import 'analytics/provider.dart';
import 'app_size/app_size_controller.dart';
import 'app_size/app_size_screen.dart';
import 'common_widgets.dart';
import 'config_specific/ide_theme/ide_theme.dart';
import 'config_specific/server/_server_stub.dart';
import 'debugger/debugger_controller.dart';
import 'debugger/debugger_screen.dart';
import 'dialogs.dart';
import 'framework/framework_core.dart';
import 'globals.dart';
import 'initializer.dart';
import 'inspector/inspector_screen.dart';
import 'landing_screen.dart';
import 'logging/logging_controller.dart';
import 'logging/logging_screen.dart';
import 'memory/memory_controller.dart';
import 'memory/memory_screen.dart';
import 'network/network_controller.dart';
import 'network/network_screen.dart';
import 'notifications.dart';
import 'performance/performance_controller.dart';
import 'performance/performance_screen.dart';
import 'preferences.dart';
import 'routing.dart';
import 'scaffold.dart';
import 'screen.dart';
import 'snapshot_screen.dart';
import 'theme.dart';
import 'timeline/timeline_controller.dart';
import 'timeline/timeline_screen.dart';
import 'ui/service_extension_widgets.dart';
import 'utils.dart';

// Disabled until VM developer mode functionality is added.
const showVmDeveloperMode = false;

/// Whether this DevTools build is external.
bool isExternalBuild = true;

/// Top-level configuration for the app.
@immutable
class DevToolsApp extends StatefulWidget {
  const DevToolsApp(
    this.screens,
    this.preferences,
    this.ideTheme,
    this.analyticsProvider,
  );

  final List<DevToolsScreen> screens;
  final PreferencesController preferences;
  final IdeTheme ideTheme;
  final AnalyticsProvider analyticsProvider;

  @override
  State<DevToolsApp> createState() => DevToolsAppState();

  static DevToolsAppState of(BuildContext context) {
    return context.findAncestorStateOfType<DevToolsAppState>();
  }
}

/// Initializer for the [FrameworkCore] and the app's navigation.
///
/// This manages the route generation, and marshalls URL query parameters into
/// flutter route parameters.
// TODO(https://github.com/flutter/devtools/issues/1146): Introduce tests that
// navigate the full app.
class DevToolsAppState extends State<DevToolsApp> {
  List<Screen> get _screens => widget.screens.map((s) => s.screen).toList();

  PreferencesController get preferences => widget.preferences;
  IdeTheme get ideTheme => widget.ideTheme;

  @override
  void initState() {
    super.initState();

    ga.setupDimensions();

    serviceManager.isolateManager.onSelectedIsolateChanged.listen((_) {
      setState(() {
        _clearCachedRoutes();
      });
    });
  }

  @override
  void didUpdateWidget(DevToolsApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _clearCachedRoutes();
  }

  /// Gets the page for a given page/path and args.
  Page _getPage(BuildContext context, String page, Map<String, String> args) {
    // Provide the appropriate page route.
    if (pages.containsKey(page)) {
      Widget widget = pages[page](
        context,
        page,
        args,
      );
      assert(() {
        widget = _AlternateCheckedModeBanner(
          builder: (context) => pages[page](
            context,
            page,
            args,
          ),
        );
        return true;
      }());
      return MaterialPage(child: widget);
    }

    // Return a page not found.
    return MaterialPage(
      child: DevToolsScaffold.withChild(
        key: const Key('not-found'),
        child: CenteredMessage("'$page' not found."),
        ideTheme: ideTheme,
        analyticsProvider: widget.analyticsProvider,
      ),
    );
  }

  Widget _buildTabbedPage(
    BuildContext context,
    String page,
    Map<String, String> params,
  ) {
    final vmServiceUri = params['uri'];

    // Always return the landing screen if there's no VM service URI.
    if (vmServiceUri?.isEmpty ?? true) {
      return DevToolsScaffold.withChild(
        key: const Key('landing'),
        child: LandingScreenBody(),
        ideTheme: ideTheme,
        analyticsProvider: widget.analyticsProvider,
        actions: [
          OpenSettingsAction(),
          OpenAboutAction(),
        ],
      );
    }

    // TODO(dantup): We should be able simplify this a little, removing params['page']
    // and only supporting /inspector (etc.) instead of also &page=inspector if
    // all IDEs switch over to those URLs.
    if (page?.isEmpty ?? true) {
      page = params['page'];
    }
    final embed = params['embed'] == 'true';
    final hide = {...?params['hide']?.split(',')};
    return Initializer(
      url: vmServiceUri,
      allowConnectionScreenOnDisconnect: !embed,
      builder: (_) {
        final tabs = _visibleScreens()
            .where((p) => embed && page != null ? p.screenId == page : true)
            .where((p) => !hide.contains(p.screenId))
            .toList();
        if (tabs.isEmpty) {
          return DevToolsScaffold.withChild(
            child: CenteredMessage(
                'The "$page" screen is not available for this application.'),
            ideTheme: ideTheme,
            analyticsProvider: widget.analyticsProvider,
          );
        }
        return _providedControllers(
          child: DevToolsScaffold(
            embed: embed,
            ideTheme: ideTheme,
            page: page,
            tabs: tabs,
            analyticsProvider: widget.analyticsProvider,
            actions: [
              // TODO(https://github.com/flutter/devtools/issues/1941)
              if (serviceManager.connectedApp.isFlutterAppNow) ...[
                HotReloadButton(),
                HotRestartButton(),
              ],
              OpenSettingsAction(),
              OpenAboutAction(),
            ],
          ),
        );
      },
    );
  }

  /// The pages that the app exposes.
  Map<String, UrlParametersBuilder> get pages {
    return _routes ??= {
      homePageId: _buildTabbedPage,
      for (final screen in widget.screens)
        screen.screen.screenId: _buildTabbedPage,
      snapshotPageId: (_, __, args) {
        final snapshotArgs = SnapshotArguments.fromArgs(args);
        return DevToolsScaffold.withChild(
          key: UniqueKey(),
          analyticsProvider: widget.analyticsProvider,
          child: _providedControllers(
            offline: true,
            child: SnapshotScreenBody(snapshotArgs, _screens),
          ),
          ideTheme: ideTheme,
        );
      },
      appSizePageId: (_, __, ___) {
        return DevToolsScaffold.withChild(
          key: const Key('appsize'),
          analyticsProvider: widget.analyticsProvider,
          child: _providedControllers(
            child: const AppSizeBody(),
          ),
          ideTheme: ideTheme,
          actions: [
            OpenSettingsAction(),
            OpenAboutAction(),
          ],
        );
      },
    };
  }

  Map<String, UrlParametersBuilder> _routes;

  void _clearCachedRoutes() {
    _routes = null;
  }

  List<Screen> _visibleScreens() => _screens.where(shouldShowScreen).toList();

  Widget _providedControllers({@required Widget child, bool offline = false}) {
    final _providers = widget.screens
        .where((s) =>
            s.createController != null && (offline ? s.supportsOffline : true))
        .map((s) => s.controllerProvider)
        .toList();

    return MultiProvider(
      providers: _providers,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.preferences.darkModeTheme,
      builder: (context, value, _) {
        return MaterialApp.router(
          title: 'Dart DevTools',
          debugShowCheckedModeBanner: false,
          theme: themeFor(isDarkTheme: value, ideTheme: ideTheme),
          builder: (context, child) => Notifications(child: child),
          routerDelegate: DevToolsRouterDelegate(_getPage),
          routeInformationParser: DevToolsRouteInformationParser(),
        );
      },
    );
  }
}

/// DevTools screen wrapper that is responsible for creating and providing the
/// screen's controller, as well as enabling offline support.
///
/// [C] corresponds to the type of the screen's controller, which is created by
/// [createController] and provided by [controllerProvider].
class DevToolsScreen<C> {
  const DevToolsScreen(
    this.screen, {
    @required this.createController,
    this.supportsOffline = false,
  });

  final Screen screen;

  /// Responsible for creating the controller for this screen, if non-null.
  ///
  /// The controller will then be provided via [controllerProvider], and
  /// widgets depending on this controller can access it by calling
  /// `Provider<C>.of(context)`.
  ///
  /// If null, [screen] will be responsible for creating and maintaining its own
  /// controller.
  final C Function() createController;

  /// Whether this screen has implemented offline support.
  ///
  /// Defaults to false.
  final bool supportsOffline;

  Provider<C> get controllerProvider {
    assert(createController != null);
    return Provider<C>(create: (_) => createController());
  }
}

/// A [WidgetBuilder] that takes an additional map of URL query parameters and
/// args.
typedef UrlParametersBuilder = Widget Function(
  BuildContext,
  String,
  Map<String, String>,
);

/// Displays the checked mode banner in the bottom end corner instead of the
/// top end corner.
///
/// This avoids issues with widgets in the appbar being hidden by the banner
/// in a web or desktop app.
class _AlternateCheckedModeBanner extends StatelessWidget {
  const _AlternateCheckedModeBanner({Key key, this.builder}) : super(key: key);
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Banner(
      message: 'DEBUG',
      textDirection: TextDirection.ltr,
      location: BannerLocation.topStart,
      child: Builder(
        builder: builder,
      ),
    );
  }
}

class OpenAboutAction extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ActionButton(
      tooltip: 'About DevTools',
      child: InkWell(
        onTap: () async {
          unawaited(showDialog(
            context: context,
            builder: (context) => DevToolsAboutDialog(),
          ));
        },
        child: Container(
          width: DevToolsScaffold.actionWidgetSize,
          height: DevToolsScaffold.actionWidgetSize,
          alignment: Alignment.center,
          child: const Icon(
            Icons.help_outline,
            size: actionsIconSize,
          ),
        ),
      ),
    );
  }
}

class OpenSettingsAction extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ActionButton(
      tooltip: 'Settings',
      child: InkWell(
        onTap: () async {
          unawaited(showDialog(
            context: context,
            builder: (context) => SettingsDialog(),
          ));
        },
        child: Container(
          width: DevToolsScaffold.actionWidgetSize,
          height: DevToolsScaffold.actionWidgetSize,
          alignment: Alignment.center,
          child: const Icon(
            Icons.settings,
            size: actionsIconSize,
          ),
        ),
      ),
    );
  }
}

class DevToolsAboutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DevToolsDialog(
      title: dialogTitleText(theme, 'About DevTools'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _aboutDevTools(context),
          const SizedBox(height: defaultSpacing),
          ...dialogSubHeader(theme, 'Feedback'),
          Wrap(
            children: [
              const Text('Encountered an issue? Let us know at '),
              _createFeedbackLink(context),
              const Text('.')
            ],
          ),
        ],
      ),
      actions: [
        DialogCloseButton(),
      ],
    );
  }

  Widget _aboutDevTools(BuildContext context) {
    return const SelectableText('DevTools version ${devtools.version}');
  }

  Widget _createFeedbackLink(BuildContext context) {
    const urlPath = 'github.com/flutter/devtools/issues';
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        ga.select(devToolsMain, feedback);

        const reportIssuesUrl = 'https://$urlPath';
        await launchUrl(reportIssuesUrl, context);
      },
      child: Text(urlPath, style: linkTextStyle(colorScheme)),
    );
  }
}

// TODO(kenz): merge the checkbox functionality here with [NotifierCheckbox]
class SettingsDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final preferences = DevToolsApp.of(context).preferences;
    return DevToolsDialog(
      title: dialogTitleText(Theme.of(context), 'Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOption(
            label: const Text('Use a dark theme'),
            listenable: preferences.darkModeTheme,
            toggle: preferences.toggleDarkModeTheme,
          ),
          if (isExternalBuild && isDevToolsServerAvailable)
            _buildOption(
              label: const Text('Enable analytics'),
              listenable: ga.gaEnabledNotifier,
              toggle: ga.setAnalyticsEnabled,
            ),
          if (showVmDeveloperMode)
            _buildOption(
              label: const Text('Enable VM developer mode'),
              listenable: preferences.vmDeveloperModeEnabled,
              toggle: preferences.toggleVmDeveloperMode,
            ),
        ],
      ),
      actions: [
        DialogCloseButton(),
      ],
    );
  }

  Widget _buildOption({
    Text label,
    ValueListenable<bool> listenable,
    Function(bool) toggle,
  }) {
    return InkWell(
      onTap: () => toggle(!listenable.value),
      child: Row(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: listenable,
            builder: (context, value, _) {
              return Checkbox(
                value: value,
                onChanged: toggle,
              );
            },
          ),
          label,
        ],
      ),
    );
  }
}

/// Screens to initialize DevTools with.
///
/// If the screen depends on a provided controller, the provider should be
/// provided here.
///
/// Conditional screens can be added to this list, and they will automatically
/// be shown or hidden based on the [Screen.conditionalLibrary] provided.
List<DevToolsScreen> get defaultScreens => <DevToolsScreen>[
      const DevToolsScreen(InspectorScreen(), createController: null),
      DevToolsScreen<TimelineController>(
        const TimelineScreen(),
        createController: () => TimelineController(),
        supportsOffline: true,
      ),
      DevToolsScreen<MemoryController>(
        const MemoryScreen(),
        createController: () => MemoryController(),
      ),
      DevToolsScreen<PerformanceController>(
        const PerformanceScreen(),
        createController: () => PerformanceController(),
        supportsOffline: true,
      ),
      DevToolsScreen<DebuggerController>(
        const DebuggerScreen(),
        createController: () => DebuggerController(),
      ),
      DevToolsScreen<NetworkController>(
        const NetworkScreen(),
        createController: () => NetworkController(),
      ),
      DevToolsScreen<LoggingController>(
        const LoggingScreen(),
        createController: () => LoggingController(),
      ),
      DevToolsScreen<AppSizeController>(
        const AppSizeScreen(),
        createController: () => AppSizeController(),
      ),
// Uncomment to see a sample implementation of a conditional screen.
//      DevToolsScreen<ExampleController>(
//        const ExampleConditionalScreen(),
//        createController: () => ExampleController(),
//        supportsOffline: true,
//      ),
    ];
