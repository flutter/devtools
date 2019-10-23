// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/ui/flutter/service_extension_widgets.dart';
import 'package:flutter/material.dart';

import '../../src/framework/framework_core.dart';
import '../../src/globals.dart';
import '../info/flutter/info_screen.dart';
import '../inspector/flutter/inspector_screen.dart';
import '../performance/flutter/performance_screen.dart';
import '../ui/theme.dart' as devtools_theme;
import 'connect_screen.dart';
import 'scaffold.dart';
import 'screen.dart';

/// Top-level configuration for the app.
@immutable
class DevToolsApp extends StatefulWidget {
  @override
  State<DevToolsApp> createState() => DevToolsAppState();
}

/// Initializer for the [FrameworkCore] and the app's navigation.
///
/// This manages the route generation, and marshalls URL query parameters into
/// flutter route parameters.
// TODO(https://github.com/flutter/devtools/issues/1146): Introduce tests that
// navigate the full app.
class DevToolsAppState extends State<DevToolsApp> {
  @override
  void initState() {
    super.initState();
  }

  /// Generates routes, separating the path from URL query parameters.
  Route _generateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name);
    final path = uri.path;

    if (_routes.containsKey(path)) {
      var builder = _routes[path];
      assert(() {
        builder =
            (context) => _AlternateCheckedModeBanner(builder: _routes[path]);
        return true;
      }());
      return MaterialPageRoute(settings: settings, builder: builder);
    }
    // Return a page not found.
    return MaterialPageRoute(
      settings: settings,
      builder: (BuildContext context) {
        return DevToolsScaffold.withChild(
          child: Center(
            child: Text(
              'Sorry, $uri was not found.',
              style: Theme.of(context).textTheme.display1,
            ),
          ),
        );
      },
    );
  }

  /// The routes that the app exposes.
  final Map<String, WidgetBuilder> _routes = {
    '/': (_) => Initializer(
          builder: (_) => DevToolsScaffold(
            tabs: [
              const InspectorScreen(),
              EmptyScreen.timeline,
              const PerformanceScreen(),
              EmptyScreen.memory,
              EmptyScreen.debugger,
              EmptyScreen.logging,
              const InfoScreen(),
            ],
            actions: [
              HotReloadButton(),
              HotRestartButton(),
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
              ),
            ],
          ),
        ),
    '/connect': (_) => DevToolsScaffold.withChild(child: ConnectScreenBody()),
  };

  @override
  Widget build(BuildContext context) {
    final theme =
        devtools_theme.isDarkTheme ? ThemeData.dark() : ThemeData.light();
    // TODO(jacobr): determine whether to update the theme to match the
    // devtools_theme or update devtools_theme to match the flutter theme.
    // For example, to match the devtools_theme we would wrtie:
    // theme.copyWith(backgroundColor: devtools_theme.defaultBackground);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      onGenerateRoute: _generateRoute,
    );
  }
}

/// Widget that requires business logic to be loaded before building its
/// [builder].
///
/// See [_InitializerState.build] for the logic that determines whether the
/// business logic is loaded.
///
/// Use this widget to wrap pages that require [service.serviceManager] to be
/// connected. As we require additional services to be available, add them
/// here.
class Initializer extends StatefulWidget {
  const Initializer({Key key, @required this.builder})
      : assert(builder != null),
        super(key: key);

  /// The builder for the widget's children.
  ///
  /// Will only be built if [_InitializerState._checkLoaded] is true.
  final WidgetBuilder builder;

  @override
  _InitializerState createState() => _InitializerState();
}

class _InitializerState extends State<Initializer> {
  final List<StreamSubscription> _subscriptions = [];

  /// Checks if the [service.serviceManager] is connected.
  ///
  /// This is a method and not a getter to communicate that its value may
  /// change between successive calls.
  bool _checkLoaded() => serviceManager.hasConnection;

  @override
  void initState() {
    super.initState();
    _subscriptions.add(
      serviceManager.onStateChange.listen((_) {
        // Generally, empty setState calls in Flutter should be avoided.
        // However, serviceManager is an implicit part of this state.
        // This setState call is alerting a change in the serviceManager's
        // state.
        setState(() {});
        // If we've become disconnected, attempt to reconnect.
        _connectToServiceManager();
      }),
    );
    _connectToServiceManager();
  }

  @override
  void dispose() {
    for (var s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  /// Loads the /connect page if the [service.serviceManager] is not currently connected.
  void _connectToServiceManager() {
    // TODO(https://github.com/flutter/devtools/issues/1150): Check the route
    // parameters for a VM Service URL and attempt to connect to it without
    // going to the /connect page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_checkLoaded() && ModalRoute.of(context).isCurrent) {
        // If this route is on top and the app is not loaded, then we navigate to
        // the /connect page to get a VM Service connection for serviceManager.
        // When it completes, the serviceManager will notify this instance.
        Navigator.of(context).pushNamed('/connect');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // SizedBox with no parameters is a generic no-op widget in Flutter.
    // Its use here means to display nothing.
    // TODO(https://github.com/flutter/devtools/issues/1150): we can add a
    // loading animation here in cases where this route will remain visible
    // and we await an attempt to connect.
    return _checkLoaded() ? widget.builder(context) : const SizedBox();
  }
}

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
      location: BannerLocation.bottomEnd,
      child: Builder(
        builder: builder,
      ),
    );
  }
}
