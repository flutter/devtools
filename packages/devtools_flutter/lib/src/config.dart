// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/services.dart' as service;
import 'package:flutter/material.dart';

import 'connect_screen.dart';
import 'scaffold.dart';
import 'screen.dart';

/// Top-level configuration for the app.
@immutable
class DevToolsApp extends StatefulWidget {
  @override
  State<DevToolsApp> createState() => DevToolsAppState();
}

/// The DevTools app's state.
///
/// This manages the route generation, and marshalls URL query parameters into flutter route parameters.
// TODO(https://github.com/flutter/devtools/issues/1146): Introduce tests that navigate the full app.
class DevToolsAppState extends State<DevToolsApp> {
  @override
  void initState() {
    super.initState();
    service.FrameworkCore.init(WidgetsBinding.instance.window.defaultRouteName);
  }

  /// Generates routes, separating the path from URL query parameters.
  Route generateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name);
    final queryParams = uri.queryParameters;
    final path = uri.path;
    print('path: $path, params: $queryParams');

    if (routes.containsKey(path)) {
      return MaterialPageRoute(settings: settings, builder: routes[path]);
    }
    // Return a page not found.
    return MaterialPageRoute(
      settings: settings,
      builder: (_) {
        return DevToolsScaffold.withChild(
          child: const Center(
            child: Text('Sorry, this page was not found'),
          ),
        );
      },
    );
  }

  /// The routes that the app exposes.
  final Map<String, WidgetBuilder> routes = {
    '/': (_) => Initializer(
          builder: (_) => const DevToolsScaffold(
            tabs: [
              EmptyScreen.inspector,
              EmptyScreen.timeline,
              EmptyScreen.performance,
              EmptyScreen.memory,
              EmptyScreen.logging,
            ],
          ),
        ),
    '/connect': (_) => DevToolsScaffold.withChild(child: ConnectScreenBody()),
  };
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      onGenerateRoute: generateRoute,
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
  /// Will only be built if [_InitializerState._loaded] is true.
  final WidgetBuilder builder;

  @override
  _InitializerState createState() => _InitializerState();
}

class _InitializerState extends State<Initializer> {
  @override
  Widget build(BuildContext context) {
    final loaded = service.serviceManager.hasConnection;

    // If the loading is not completed, navigate to the connection page to
    // connect to a VM service.
    if (!loaded && ModalRoute.of(context).isCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamed('/connect').then((_) {
          // Generally, empty setState calls in Flutter should be avoided.
          // However, serviceManager is an implicit part of the state
          // of Initializer. This setState call is alerting the widget of a change
          // in the serviceManager's state.
          setState(() {});
        });
      });
    }

    return loaded ? widget.builder(context) : const SizedBox();
  }
}
