// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const appSizePageId = 'app-size';
const homePageId = '';
const snapshotPageId = 'snapshot';

class DevToolsRouteConfiguration {
  DevToolsRouteConfiguration(this.page, this.args);

  final String page;
  final Map<String, String> args;

  RouteInformation toRouteInformation() {
    final path = '/${page ?? ''}';
    final params = (args?.length ?? 0) != 0 ? args : null;
    return RouteInformation(
        location: Uri(path: path, queryParameters: params).toString());
  }

  static DevToolsRouteConfiguration fromRouteInformation(
      RouteInformation routeInformation) {
    final uri = Uri.parse(routeInformation.location);
    return DevToolsRouteConfiguration(
        uri.path.substring(1), uri.queryParameters);
  }
}

class DevToolsRouteInformationParser
    extends RouteInformationParser<DevToolsRouteConfiguration> {
  @override
  Future<DevToolsRouteConfiguration> parseRouteInformation(
          RouteInformation routeInformation) =>
      SynchronousFuture<DevToolsRouteConfiguration>(
          DevToolsRouteConfiguration.fromRouteInformation(routeInformation));

  @override
  RouteInformation restoreRouteInformation(
          DevToolsRouteConfiguration configuration) =>
      configuration.toRouteInformation();
}

class DevToolsRouterDelegate extends RouterDelegate<DevToolsRouteConfiguration>
    with
        ChangeNotifier,
        PopNavigatorRouterDelegateMixin<DevToolsRouteConfiguration> {
  DevToolsRouterDelegate(this._getPage)
      : navigatorKey = GlobalKey<NavigatorState>();

  static DevToolsRouterDelegate of(BuildContext context) =>
      Router.of(context).routerDelegate as DevToolsRouterDelegate;

  @override
  final GlobalKey<NavigatorState> navigatorKey;
  final Page Function(BuildContext, String, Map<String, String>) _getPage;
  final routes = ListQueue<DevToolsRouteConfiguration>();

  @override
  DevToolsRouteConfiguration get currentConfiguration =>
      routes.isEmpty ? null : routes.last;

  @override
  Widget build(BuildContext context) {
    final routeConfig = routes.last;
    final page = routeConfig.page;
    final args = routeConfig.args ?? {};

    return Navigator(
      key: navigatorKey,
      pages: [_getPage(context, page, args)],
      onPopPage: (route, result) => popPage(),
    );
  }

  bool popPage() {
    if (routes.length <= 1) {
      return false;
    }

    routes.removeLast();
    notifyListeners();
    return true;
  }

  /// Pushes a new page, optionally updating arguments.
  ///
  /// Existing arguments (for example &uri=) will be preserved unless
  /// overwritten by [updateArgs].
  void pushPageIfNotCurrent(String page, [Map<String, String> updateArgs]) {
    final pageChanged = page != currentConfiguration.page;
    final argsChanged = !mapEquals(
      {...currentConfiguration.args, ...?updateArgs},
      currentConfiguration.args,
    );
    if (!pageChanged && !argsChanged) {
      return;
    }

    routes.add(DevToolsRouteConfiguration(
        page, {...currentConfiguration.args, ...?updateArgs}));

    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(DevToolsRouteConfiguration configuration) {
    routes.add(configuration);
    return SynchronousFuture<void>(null);
  }

  /// Updates arguments for the current page.
  ///
  /// Existing arguments (for example &uri=) will be preserved unless
  /// overwritten by [updateArgs].
  void updateArgsIfNotCurrent(Map<String, String> updateArgs) {
    final argsChanged = !mapEquals(
      {...currentConfiguration.args, ...?updateArgs},
      currentConfiguration.args,
    );
    if (!argsChanged) {
      return;
    }

    routes.add(DevToolsRouteConfiguration(
      currentConfiguration.page,
      {...currentConfiguration.args, ...updateArgs},
    ));

    notifyListeners();
  }
}
