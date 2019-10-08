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
class Config {
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
  Map<String, WidgetBuilder> get routes => {
        '/': (_) => Prerequisite(
              condition: () => service.serviceManager.hasConnection,
              route: '/connect',
              builder: (_) => const DevToolsScaffold(tabs: [
                EmptyScreen.inspector,
                EmptyScreen.timeline,
                EmptyScreen.performance,
                EmptyScreen.memory,
                EmptyScreen.logging,
              ]),
            ),
        '/connect': (_) => const DevToolsScaffold(tabs: [ConnectScreen()]),
      };
}

/// Widget that enforces a prerequisite before building its children.
///
/// The widget will pusth [route] if [condition] is false.
/// Otherwise, the widget will build [builder].
class Prerequisite extends StatefulWidget {
  const Prerequisite(
      {Key key,
      @required this.condition,
      @required this.route,
      @required this.builder})
      : assert(condition != null),
        assert(route != null),
        assert(builder != null),
        super(key: key);

  /// The
  final bool Function() condition;
  final String route;
  final WidgetBuilder builder;

  @override
  _PrerequisiteState createState() => _PrerequisiteState();
}

class _PrerequisiteState extends State<Prerequisite> {
  @override
  Widget build(BuildContext context) {
    if (ModalRoute.of(context).isCurrent && !widget.condition()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamed(widget.route).then((_) {
          setState(() {});
        });
      });
      return const SizedBox();
    }
    return widget.builder(context);
  }
}
