// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../src/framework/framework_core.dart';
import '../info/flutter/info_screen.dart';
import '../inspector/flutter/inspector_screen.dart';
import '../logging/flutter/logging_screen.dart';
import '../memory/flutter/memory_screen.dart';
import '../performance/flutter/performance_screen.dart';
import '../timeline/flutter/timeline_screen.dart';
import '../ui/flutter/service_extension_widgets.dart';
import '../ui/theme.dart' as devtools_theme;
import 'connect_screen.dart';
import 'initializer.dart';
import 'scaffold.dart';
import 'theme.dart';

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
  ThemeData theme;

  @override
  void initState() {
    super.initState();
    theme = themeFor(isDarkTheme: devtools_theme.isDarkTheme);
  }

  /// Generates routes, separating the path from URL query parameters.
  Route _generateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name);
    final path = uri.path;

    // Update the theme based on the query parameters.
    // TODO(djshuckerow): Update this with a NavigatorObserver to load the
    // new theme a frame earlier.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // On desktop, don't change the theme on route changes.
      if (!kIsWeb) return;
      setState(() {
        final themeQueryParameter = uri.queryParameters['theme'];
        // We refer to the legacy theme to make sure the
        // debugging page stays in-sync with the rest of the app.
        devtools_theme.initializeTheme(themeQueryParameter);
        theme = themeFor(isDarkTheme: devtools_theme.isDarkTheme);
      });
    });

    // Provide the appropriate page route.
    if (_routes.containsKey(path)) {
      WidgetBuilder builder =
          (context) => _routes[path](context, uri.queryParameters);
      assert(() {
        builder = (context) => _AlternateCheckedModeBanner(
              builder: (context) => _routes[path](
                context,
                uri.queryParameters,
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
  final Map<String, UrlParametersBuilder> _routes = {
    '/': (_, params) => Initializer(
          url: params['uri'],
          builder: (_) => DevToolsScaffold(
            tabs: const [
              InspectorScreen(),
              TimelineScreen(),
              MemoryScreen(),
              PerformanceScreen(),
              // TODO(https://github.com/flutter/flutter/issues/43783): Put back
              // the debugger screen.
              LoggingScreen(),
              InfoScreen(),
            ],
            actions: [
              HotReloadButton(),
              HotRestartButton(),
            ],
          ),
        ),
    '/connect': (_, __) =>
        DevToolsScaffold.withChild(child: ConnectScreenBody()),
  };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      onGenerateRoute: _generateRoute,
    );
  }
}

/// A [WidgetBuilder] that takes an additional map of URL query parameters.
typedef UrlParametersBuilder = Widget Function(
  BuildContext,
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
      location: BannerLocation.bottomEnd,
      child: Builder(
        builder: builder,
      ),
    );
  }
}
