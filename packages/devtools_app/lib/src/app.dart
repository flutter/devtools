// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/drag_and_drop/drag_and_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pedantic/pedantic.dart';
import 'package:provider/provider.dart';

import '../devtools.dart' as devtools;
import 'code_size/code_size_controller.dart';
import 'code_size/code_size_screen.dart';
import 'common_widgets.dart';
import 'config_specific/ide_theme/ide_theme.dart';
import 'connect_screen.dart';
import 'debugger/debugger_controller.dart';
import 'debugger/debugger_screen.dart';
import 'dialogs.dart';
import 'framework/framework_core.dart';
import 'globals.dart';
import 'initializer.dart';
import 'inspector/inspector_screen.dart';
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
import 'scaffold.dart';
import 'screen.dart';
import 'snapshot_screen.dart';
import 'theme.dart';
import 'timeline/timeline_controller.dart';
import 'timeline/timeline_screen.dart';
import 'ui/service_extension_widgets.dart';
import 'utils.dart';

const homeRoute = '/';
const snapshotRoute = '/snapshot';

/// Top-level configuration for the app.
@immutable
class DevToolsApp extends StatefulWidget {
  const DevToolsApp(this.screens, this.preferences, this.ideTheme);

  final List<DevToolsScreen> screens;
  final PreferencesController preferences;
  final IdeTheme ideTheme;

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

  /// Generates routes, separating the path from URL query parameters.
  Route _generateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name);
    final path = uri.path.isEmpty ? homeRoute : uri.path;
    final args = settings.arguments;

    // Provide the appropriate page route.
    if (routes.containsKey(path)) {
      WidgetBuilder builder = (context) => routes[path](
            context,
            uri.queryParameters,
            args,
          );
      assert(() {
        builder = (context) => _AlternateCheckedModeBanner(
              builder: (context) => routes[path](
                context,
                uri.queryParameters,
                args,
              ),
            );
        return true;
      }());
      return MaterialPageRoute(settings: settings, builder: builder);
    }

    // Return a page not found.
    return MaterialPageRoute(
      settings: settings,
      builder: (BuildContext context) {
        return DevToolsScaffold.withChild(
          dragAndDropId: 'Scaffold - URI not found - dragAndDropKey',
          child: CenteredMessage("'$uri' not found."),
          ideTheme: ideTheme,
        );
      },
    );
  }

  /// The routes that the app exposes.
  Map<String, UrlParametersBuilder> get routes {
    return _routes ??= {
      homeRoute: (_, params, __) {
        if (params['uri']?.isNotEmpty ?? false) {
          final embed = params['embed'] == 'true';
          final page = params['page'];
          final tabs = embed && page != null
              ? _visibleScreens().where((p) => p.screenId == page).toList()
              : _visibleScreens();
          return Initializer(
            url: params['uri'],
            allowConnectionScreenOnDisconnect: !embed,
            builder: (_) => _providedControllers(
              child: DevToolsScaffold(
                embed: embed,
                ideTheme: ideTheme,
                initialPage: page,
                tabs: tabs,
                dragAndDropId: 'Scaffold - main - dragAndDropKey',
                actions: [
                  if (serviceManager.connectedApp.isFlutterAppNow) ...[
                    HotReloadButton(),
                    HotRestartButton(),
                  ],
                  OpenSettingsAction(),
                  OpenAboutAction(),
                ],
              ),
            ),
          );
        } else {
          return DevToolsScaffold.withChild(
            child: ConnectScreenBody(),
            ideTheme: ideTheme,
            dragAndDropId: 'Scaffold - connect screen - dragAndDropKey',
          );
        }
      },
      snapshotRoute: (_, __, args) {
        return DevToolsScaffold.withChild(
          dragAndDropId: 'Scaffold - snapshot screen - dragAndDropKey',
          child: _providedControllers(
            offline: true,
            child: SnapshotScreenBody(args, _screens),
          ),
          ideTheme: ideTheme,
        );
      },
    };
  }

  Map<String, UrlParametersBuilder> _routes;

  void _clearCachedRoutes() {
    _routes = null;
  }

  List<Screen> _visibleScreens() {
    final visibleScreens = <Screen>[];
    for (var screen in _screens) {
      if (screen.conditionalLibrary != null) {
        if (serviceManager.isServiceAvailable &&
            serviceManager
                .isolateManager.selectedIsolateAvailable.isCompleted &&
            serviceManager.libraryUriAvailableNow(screen.conditionalLibrary)) {
          visibleScreens.add(screen);
        }
      } else {
        visibleScreens.add(screen);
      }
    }
    return visibleScreens;
  }

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
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: themeFor(isDarkTheme: value, ideTheme: ideTheme),
          builder: (context, child) => Notifications(
            child: DragAndDropManagerProvider(child: child),
          ),
          onGenerateRoute: _generateRoute,
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
  Map<String, String>,
  SnapshotArguments args,
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
        // TODO(devoncarew): Support analytics.
        // ga.select(ga.devToolsMain, ga.feedback);

        const reportIssuesUrl = 'https://$urlPath';
        await launchUrl(reportIssuesUrl, context);
      },
      child: Text(urlPath, style: linkTextStyle(colorScheme)),
    );
  }
}

// TODO(devoncarew): Add an analytics setting.

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
          InkWell(
            onTap: () {
              preferences.toggleDarkModeTheme(!preferences.darkModeTheme.value);
            },
            child: Row(
              children: [
                ValueListenableBuilder(
                  valueListenable: preferences.darkModeTheme,
                  builder: (context, value, _) {
                    return Checkbox(
                      value: value,
                      onChanged: (bool value) {
                        preferences.toggleDarkModeTheme(value);
                      },
                    );
                  },
                ),
                const Text('Use a dark theme'),
              ],
            ),
          ),
        ],
      ),
      actions: [
        DialogCloseButton(),
      ],
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
      if (codeSizeScreenEnabled)
        DevToolsScreen<CodeSizeController>(
          const CodeSizeScreen(),
          createController: () => CodeSizeController(),
        ),
// Uncomment to see a sample implementation of a conditional screen.
//      DevToolsScreen<ExampleController>(
//        const ExampleConditionalScreen(),
//        createController: () => ExampleController(),
//        supportsOffline: true,
//      ),
    ];
