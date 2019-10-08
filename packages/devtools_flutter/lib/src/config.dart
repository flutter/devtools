// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'connect_screen.dart';
import 'scaffold.dart';
import 'screen.dart';

/// Top-level configuration for the app.
@immutable
class Config {
  /// The routes that the app exposes.
  Map<String, WidgetBuilder> get routes {
    final routeToBuilder = <String, WidgetBuilder>{};
    for (var key in _routeToTabs.keys) {
      routeToBuilder[key] =
          (BuildContext context) => DevToolsScaffold(tabs: _routeToTabs[key]);
    }
    return routeToBuilder;
  }

  // The mapping from routes to the collection of screens to show in the app.
  //
  // The /connect route will be a dependency for all the other routes.
  final Map<String, List<Screen>> _routeToTabs = const {
    '/': [ConnectScreen()],
    '/connected': [
      EmptyScreen.inspector,
      EmptyScreen.timeline,
      EmptyScreen.performance,
      EmptyScreen.memory,
      EmptyScreen.logging,
    ],
  };
}
