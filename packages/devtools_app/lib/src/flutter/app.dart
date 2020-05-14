// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html';

import 'package:devtools_app/src/config_specific/html/html.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pedantic/pedantic.dart';
import 'package:provider/provider.dart';

import '../../devtools.dart' as devtools;
import '../debugger/flutter/debugger_controller.dart';
import '../debugger/flutter/debugger_screen.dart';
import '../framework/framework_core.dart';
import '../framework_controller.dart';
import '../globals.dart';
import '../info/flutter/info_screen.dart';
import '../inspector/flutter/inspector_screen.dart';
import '../logging/flutter/logging_screen.dart';
import '../logging/logging_controller.dart';
import '../memory/flutter/memory_controller.dart';
import '../memory/flutter/memory_screen.dart';
import '../network/flutter/network_screen.dart';
import '../network/network_controller.dart';
import '../performance/flutter/performance_screen.dart';
import '../performance/performance_controller.dart';
import '../timeline/flutter/timeline_controller.dart';
import '../timeline/flutter/timeline_screen.dart';
import '../ui/flutter/service_extension_widgets.dart';
import 'common_widgets.dart';
import 'connect_screen.dart';
import 'initializer.dart';
import 'navigation.dart';
import 'notifications.dart';
import 'preferences.dart';
import 'scaffold.dart';
import 'screen.dart';
import 'snapshot_screen.dart';
import 'theme.dart';
import 'utils.dart';

const homeRoute = '/';
const snapshotRoute = '/snapshot';

/// Top-level configuration for the app.
@immutable
class DevToolsApp extends StatefulWidget {
  const DevToolsApp(this.screens);

  final List<DevToolsScreen> screens;

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
  final preferences = PreferencesController();
  StreamSubscription<ConnectVmEvent> _connectVmSubscription;

  List<Screen> get _screens => widget.screens.map((s) => s.screen).toList();

  @override
  void initState() {
    super.initState();

    serviceManager.isolateManager.onSelectedIsolateChanged.listen((_) {
      setState(() {
        _clearCachedRoutes();
      });
    });
    _connectVmSubscription =
        frameworkController.onConnectVmEvent.listen((event) {
      final routeName = routeNameWithQueryParams(context, '/', {
        'uri': event.serviceProtocolUri.toString(),
        if (event.notify) 'notify': 'true',
      });
      // TODO(dantup): This should be something like:
      //   Navigator.of(context).pushNamed(routeName);
      // however that NPEs inside pushNamed (perhaps context isn't valid here?).
      // Currently, this code can only be invoked through the server, which means
      // we're guaranteed to be running in a web app. Outside of web, this will
      // throw.
      Html.navigateTo('/#$routeName');
    });
  }

  @override
  void dispose() {
    _connectVmSubscription?.cancel();
    super.dispose();
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
          child: CenteredMessage("'$uri' not found."),
        );
      },
    );
  }

  /// The routes that the app exposes.
  Map<String, UrlParametersBuilder> get routes {
    return _routes ??= {
      homeRoute: (_, params, __) {
        if (params['uri']?.isNotEmpty ?? false) {
          return Initializer(
            url: params['uri'],
            builder: (_) => _providedControllers(
              child: DevToolsScaffold(
                initialPage: params['page'],
                tabs: _visibleScreens(),
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
          return DevToolsScaffold.withChild(child: ConnectScreenBody());
        }
      },
      snapshotRoute: (_, __, args) {
        return DevToolsScaffold.withChild(
          child: _providedControllers(
            offline: true,
            child: SnapshotScreenBody(args, _screens),
          ),
        );
      }
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
      valueListenable: preferences.darkModeTheme,
      builder: (context, value, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: themeFor(isDarkTheme: value),
          builder: (context, child) => Notifications(child: child),
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
            Icons.info_outline,
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
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      actions: [
        DialogCloseButton(),
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...headerInColumn(textTheme, 'About DevTools'),
          _aboutDevTools(context),
          const SizedBox(height: defaultSpacing),
          ...headerInColumn(textTheme, 'Feedback'),
          Wrap(
            children: [
              const Text('Encountered an issue? Let us know at '),
              _createFeedbackLink(context, textTheme),
              const Text('.')
            ],
          ),
        ],
      ),
    );
  }

  Widget _aboutDevTools(BuildContext context) {
    return const SelectableText('DevTools version ${devtools.version}');
  }

  Widget _createFeedbackLink(BuildContext context, TextTheme textTheme) {
    const urlPath = 'github.com/flutter/devtools/issues';

    return InkWell(
      onTap: () async {
        // TODO(devoncarew): Support analytics.
        // ga.select(ga.devToolsMain, ga.feedback);

        const reportIssuesUrl = 'https://$urlPath';
        await launchUrl(reportIssuesUrl, context);
      },
      child: Text(
        urlPath,
        style: textTheme.bodyText2.copyWith(
          decoration: TextDecoration.underline,
          color: devtoolsLink,
        ),
      ),
    );
  }
}

// TODO(devoncarew): Add an analytics setting.

class SettingsDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final preferences = DevToolsApp.of(context).preferences;

    return AlertDialog(
      actions: [
        DialogCloseButton(),
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...headerInColumn(Theme.of(context).textTheme, 'Settings'),
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
        createController: () => LoggingController(
          onLogCountStatusChanged: (_) {
            // TODO(devoncarew): This callback is not used.
          },
          // TODO(djshuckerow): Use a notifier pattern for the logging controller.
          // That way, it is visible if it has listeners and invisible otherwise.
          isVisible: () => true,
        ),
      ),
      const DevToolsScreen(InfoScreen(), createController: null),
// Uncomment to see a sample implementation of a conditional screen.
//      DevToolsScreen<ExampleController>(
//        const ExampleConditionalScreen(),
//        createController: () => ExampleController(),
//        supportsOffline: true,
//      ),
    ];
