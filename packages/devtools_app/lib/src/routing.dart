// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const appSizePageId = 'app-size';
const homePageId = '';
const snapshotPageId = 'snapshot';

/// Represents a Page/route for a DevTools screen.
class DevToolsRouteConfiguration {
  DevToolsRouteConfiguration(this.page, this.args);

  final String page;
  final Map<String, String> args;
}

/// Converts between structured DevToolsRouteConfiguration (our internal data
/// for pages/routing) and RouteInformation (generic data that can be persisted
/// in the address bar/state objects).
class DevToolsRouteInformationParser
    extends RouteInformationParser<DevToolsRouteConfiguration> {
  @override
  Future<DevToolsRouteConfiguration> parseRouteInformation(
      RouteInformation routeInformation) {
    final uri = Uri.parse(routeInformation.location);
    // routeInformation.path comes from the address bar and (when not empty) is
    // prefixed with a leading slash. Internally we use "page IDs" that do not
    // start with slashes but match the screenId for each screen.
    final path = uri.path.isNotEmpty ? uri.path.substring(1) : '';
    final configuration = DevToolsRouteConfiguration(path, uri.queryParameters);
    return SynchronousFuture<DevToolsRouteConfiguration>(configuration);
  }

  @override
  RouteInformation restoreRouteInformation(
    DevToolsRouteConfiguration configuration,
  ) {
    // Add a leading slash to convert the page ID to a URL path (this is
    // the opposite of what's done in [parseRouteInformation]).
    final path = '/${configuration.page ?? ''}';
    // Create a new map in case the one we were given was unmodifiable.
    final params = {...?configuration.args};
    params?.removeWhere((key, value) => value == null);
    return RouteInformation(
        location: Uri(path: path, queryParameters: params).toString());
  }
}

class DevToolsRouterDelegate extends RouterDelegate<DevToolsRouteConfiguration>
    with
        ChangeNotifier,
        PopNavigatorRouterDelegateMixin<DevToolsRouteConfiguration> {
  DevToolsRouterDelegate(this._getPage, [GlobalKey<NavigatorState> key])
      : navigatorKey = key ?? GlobalKey<NavigatorState>();

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
    final routeConfig = currentConfiguration;
    final page = routeConfig?.page;
    final args = routeConfig?.args ?? {};

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
  /// If page and args would be the same, does nothing.
  /// Existing arguments (for example &uri=) will be preserved unless
  /// overwritten by [updateArgs].
  void pushPageIfNotCurrent(String page, [Map<String, String> argUpdates]) {
    final pageChanged = page != currentConfiguration.page;
    final argsChanged = _changesArgs(argUpdates);
    if (!pageChanged && !argsChanged) {
      return;
    }

    routes.add(DevToolsRouteConfiguration(
      page,
      {...currentConfiguration.args, ...?argUpdates},
    ));

    notifyListeners();
  }

  /// Replaces a page, optionally updating arguments.
  ///
  /// If there is no current page, the new page will still be pushed.
  /// Existing arguments (for example &uri=) will be preserved unless
  /// overwritten by [updateArgs].
  void replaceCurrent(String page, [Map<String, String> argUpdates]) {
    // TODO(dantup): This does not appear to work.. clicking back in the browser
    // will still navigate to that previous page.
    final newArgs = {...currentConfiguration.args, ...?argUpdates};
    if (routes.isNotEmpty) {
      routes.removeLast();
    }
    routes.add(DevToolsRouteConfiguration(page, newArgs));

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
  /// overwritten by [argUpdates].
  void updateArgsIfNotCurrent(Map<String, String> argUpdates) {
    final argsChanged = _changesArgs(argUpdates);
    if (!argsChanged) {
      return;
    }

    routes.add(DevToolsRouteConfiguration(
      currentConfiguration.page,
      {...currentConfiguration.args, ...argUpdates},
    ));

    notifyListeners();
  }

  /// Checks whether applying [changes] over the current routes args will result
  /// in any changes.
  bool _changesArgs(Map<String, String> changes) => !mapEquals(
        {...?currentConfiguration.args, ...?changes},
        {...?currentConfiguration.args},
      );
}
