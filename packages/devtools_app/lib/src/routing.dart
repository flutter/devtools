// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The page ID (used in routing) for the standalone app-size page.
///
/// This must be different to the AppSizeScreen ID which is also used in routing when
/// cnnected to a VM to ensure they have unique URLs.
const appSizePageId = 'appsize';

const homePageId = '';
const snapshotPageId = 'snapshot';

/// Represents a Page/route for a DevTools screen.
class DevToolsRouteConfiguration {
  DevToolsRouteConfiguration(this.page, this.args);

  final String page;
  final Map<String, String> args;
}

/// Converts between structured [DevToolsRouteConfiguration] (our internal data
/// for pages/routing) and [RouteInformation] (generic data that can be persisted
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

  /// A list of any routes/pages on the stack.
  ///
  /// This will usually only contain a single item (it's the visible stack,
  /// not the history).
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
      onPopPage: _handleOnPopPage,
    );
  }

  bool _handleOnPopPage(Route<dynamic> route, dynamic result) {
    if (routes.length <= 1) {
      return false;
    }

    routes.removeLast();
    notifyListeners();
    return true;
  }

  /// Navigates to a new page, optionally updating arguments.
  ///
  /// If page and args would be the same, does nothing.
  /// Existing arguments (for example &uri=) will be preserved unless
  /// overwritten by [argUpdates].
  void navigateIfNotCurrent(String page, [Map<String, String> argUpdates]) {
    final pageChanged = page != currentConfiguration.page;
    final argsChanged = _changesArgs(argUpdates);
    if (!pageChanged && !argsChanged) {
      return;
    }

    navigate(page, argUpdates);
  }

  /// Navigates to a new page, optionally updating arguments.
  ///
  /// Existing arguments (for example &uri=) will be preserved unless
  /// overwritten by [argUpdates].
  void navigate(String page, [Map<String, String> argUpdates]) {
    final newArgs = {...currentConfiguration.args, ...?argUpdates};
    _replaceStack(DevToolsRouteConfiguration(page, newArgs));
    notifyListeners();
  }

  /// Replaces the navigation stack with a new route.
  void _replaceStack(DevToolsRouteConfiguration configuration) {
    routes
      ..clear()
      ..add(configuration);
  }

  @override
  Future<void> setNewRoutePath(DevToolsRouteConfiguration configuration) {
    _replaceStack(configuration);
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

    final currentPage = currentConfiguration.page;
    final newArgs = {...currentConfiguration.args, ...?argUpdates};
    _replaceStack(DevToolsRouteConfiguration(currentPage, newArgs));
    notifyListeners();
  }

  /// Checks whether applying [changes] over the current routes args will result
  /// in any changes.
  bool _changesArgs(Map<String, String> changes) => !mapEquals(
        {...?currentConfiguration.args, ...?changes},
        {...?currentConfiguration.args},
      );
}
