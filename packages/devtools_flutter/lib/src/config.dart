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
/// See [_InitializerState._loaded] for the logic that determines whether the
/// business logic is loaded.
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
  /// Determines if the VM [serviceManager] is ready for use.
  ///
  /// The only page that doesn't need this is '/connect'.
  bool get _loaded => service.serviceManager.hasConnection;

  @override
  Widget build(BuildContext context) {
    if (ModalRoute.of(context).isCurrent && !_loaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamed('/connect').then((_) {
          setState(() {});
        });
      });
      return const SizedBox();
    }
    return widget.builder(context);
  }
}
