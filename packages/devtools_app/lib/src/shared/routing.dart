// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../framework/framework_core.dart';
import 'globals.dart';
import 'primitives/utils.dart';
import 'query_parameters.dart';

const memoryAnalysisScreenId = 'memoryanalysis';

const homeScreenId = '';
const snapshotScreenId = 'snapshot';

/// Represents a Page/route for a DevTools screen.
class DevToolsRouteConfiguration {
  DevToolsRouteConfiguration(this.page, this.params, this.state);

  final String page;
  final DevToolsQueryParams params;
  final DevToolsNavigationState? state;
}

/// Converts between structured [DevToolsRouteConfiguration] (our internal data
/// for pages/routing) and [RouteInformation] (generic data that can be persisted
/// in the address bar/state objects).
class DevToolsRouteInformationParser
    extends RouteInformationParser<DevToolsRouteConfiguration> {
  DevToolsRouteInformationParser();

  @visibleForTesting
  DevToolsRouteInformationParser.test(this._testQueryParams);

  /// Query parameters that can be set on DevTools routes for testing purposes.
  ///
  /// This is to be used in a testing environment only and can be set via the
  /// [DevToolsRouteInformationParser.test] constructor.
  DevToolsQueryParams? _testQueryParams;

  @override
  Future<DevToolsRouteConfiguration> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    var uri = routeInformation.uri;
    if (_testQueryParams != null) {
      uri = uri.copyWith(queryParameters: _testQueryParams!.params);
    }

    final uriFromParams = uri.queryParameters['uri'];
    if (uriFromParams == null) {
      // If the uri has been modified and we do not have a vm service uri as a
      // query parameter, ensure we manually disconnect from any previously
      // connected applications.
      await serviceConnection.serviceManager.manuallyDisconnect();
    } else if (_testQueryParams == null) {
      // Otherwise, connect to the vm service from the query parameter before
      // loading the route (but do not do this in a testing environment).
      await FrameworkCore.initVmService(serviceUriAsString: uriFromParams);
    }

    // routeInformation.path comes from the address bar and (when not empty) is
    // prefixed with a leading slash. Internally we use "page IDs" that do not
    // start with slashes but match the screenId for each screen.
    final path = uri.path.isNotEmpty ? uri.path.substring(1) : '';
    final configuration = DevToolsRouteConfiguration(
      path,
      DevToolsQueryParams(uri.queryParameters),
      _navigationStateFromRouteInformation(routeInformation),
    );
    return SynchronousFuture<DevToolsRouteConfiguration>(configuration);
  }

  @override
  RouteInformation restoreRouteInformation(
    DevToolsRouteConfiguration configuration,
  ) {
    // Add a leading slash to convert the page ID to a URL path (this is
    // the opposite of what's done in [parseRouteInformation]).
    final path = '/${configuration.page}';
    // Create a new map in case the one we were given was unmodifiable.
    final params = {...configuration.params.params};
    params.removeWhere((key, value) => value == null);
    return RouteInformation(
      uri: Uri(path: path, queryParameters: params),
      state: configuration.state,
    );
  }

  DevToolsNavigationState? _navigationStateFromRouteInformation(
    RouteInformation routeInformation,
  ) {
    final routeState = routeInformation.state;
    if (routeState == null) return null;
    try {
      return DevToolsNavigationState._(
        (routeState as Map).cast<String, String?>(),
      );
    } catch (_) {
      return null;
    }
  }
}

class DevToolsRouterDelegate extends RouterDelegate<DevToolsRouteConfiguration>
    with
        ChangeNotifier,
        PopNavigatorRouterDelegateMixin<DevToolsRouteConfiguration> {
  DevToolsRouterDelegate(this._getPage, [GlobalKey<NavigatorState>? key])
      : navigatorKey = key ?? GlobalKey<NavigatorState>();

  static DevToolsRouterDelegate of(BuildContext context) =>
      Router.of(context).routerDelegate as DevToolsRouterDelegate;

  @override
  final GlobalKey<NavigatorState> navigatorKey;

  static String? get currentPage => _currentPage;
  static String? _currentPage;

  final Page Function(
    BuildContext,
    String?,
    DevToolsQueryParams,
    DevToolsNavigationState?,
  ) _getPage;

  /// A list of any routes/pages on the stack.
  ///
  /// This will usually only contain a single item (it's the visible stack,
  /// not the history).
  final _routes = ListQueue<DevToolsRouteConfiguration>();

  @override
  DevToolsRouteConfiguration? get currentConfiguration => _routes.lastOrNull;

  @override
  Widget build(BuildContext context) {
    final routeConfig = currentConfiguration;
    final page = routeConfig?.page;
    final params = routeConfig?.params ?? DevToolsQueryParams.empty();
    final state = routeConfig?.state;

    return Navigator(
      key: navigatorKey,
      pages: [_getPage(context, page, params, state)],
      onDidRemovePage: (_) {
        if (_routes.length <= 1) return;
        _routes.removeLast();
        notifyListeners();
      },
    );
  }

  /// Refreshes the pages for the Navigator created in [build].
  ///
  /// Call this when the DevTools pages need to be regenerated from [_getPage].
  /// This may happen when some condition changes that would cause a DevTools
  /// page to be added or removed (e.g. a DevTools extension became available
  /// or was disabled).
  void refreshPages() {
    notifyListeners();
  }

  /// Navigates to a new page, optionally updating arguments and state.
  ///
  /// If page, args, and state would be the same, does nothing.
  /// Existing arguments (for example &uri=) will be preserved unless
  /// overwritten by [argUpdates].
  void navigateIfNotCurrent(
    String page, [
    Map<String, String?>? argUpdates,
    DevToolsNavigationState? stateUpdates,
  ]) {
    final pageChanged = page != currentConfiguration!.page;
    final argsChanged = _changesArgs(argUpdates);
    final stateChanged = _changesState(stateUpdates);
    if (!pageChanged && !argsChanged && !stateChanged) {
      return;
    }

    navigate(page, argUpdates, stateUpdates);
  }

  /// Navigates to a new page, optionally updating arguments and state.
  ///
  /// Existing arguments (for example &uri=) will be preserved unless
  /// overwritten by [argUpdates].
  void navigate(
    String page, [
    Map<String, String?>? argUpdates,
    DevToolsNavigationState? state,
  ]) {
    final newParams = currentConfiguration?.params.withUpdates(argUpdates) ??
        DevToolsQueryParams.empty();

    // Ensure we disconnect from any previously connected applications if we do
    // not have a vm service uri as a query parameter, unless we are loading an
    // offline file.
    if (page != snapshotScreenId && newParams.vmServiceUri == null) {
      unawaited(serviceConnection.serviceManager.manuallyDisconnect());
    }

    _replaceStack(
      DevToolsRouteConfiguration(page, newParams, state),
    );
    notifyListeners();
  }

  void navigateHome({
    bool clearUriParam = false,
    required bool clearScreenParam,
  }) {
    navigate(
      homeScreenId,
      {
        if (clearUriParam) 'uri': null,
        if (clearScreenParam) 'screen': null,
      },
    );
  }

  /// Replaces the navigation stack with a new route.
  void _replaceStack(DevToolsRouteConfiguration configuration) {
    _currentPage = configuration.page;
    _routes
      ..clear()
      ..add(configuration);
  }

  @override
  Future<void> setNewRoutePath(DevToolsRouteConfiguration configuration) {
    _replaceStack(configuration);
    notifyListeners();
    return SynchronousFuture<void>(null);
  }

  /// Updates arguments for the current page.
  ///
  /// Existing arguments (for example &uri=) will be preserved unless
  /// overwritten by [argUpdates].
  void updateArgsIfChanged(Map<String, String> argUpdates) {
    final argsChanged = _changesArgs(argUpdates);
    if (!argsChanged) {
      return;
    }

    final currentConfig = currentConfiguration!;
    final currentPage = currentConfig.page;
    final newArgs = currentConfig.params.withUpdates(argUpdates);
    _replaceStack(
      DevToolsRouteConfiguration(
        currentPage,
        newArgs,
        currentConfig.state,
      ),
    );
    notifyListeners();
  }

  Future<void> replaceState(DevToolsNavigationState state) async {
    final currentConfig = currentConfiguration!;
    _replaceStack(
      DevToolsRouteConfiguration(
        currentConfig.page,
        currentConfig.params,
        state,
      ),
    );

    final path = '/${currentConfig.page}';
    // Create a new map in case the one we were given was unmodifiable.
    final params = Map.of(currentConfig.params.params);
    params.removeWhere((key, value) => value == null);
    await SystemNavigator.routeInformationUpdated(
      uri: Uri(path: path, queryParameters: params),
      state: state,
      replace: true,
    );
  }

  /// Updates state for the current page.
  ///
  /// Existing state will be preserved unless overwritten by [stateUpdate].
  void updateStateIfChanged(DevToolsNavigationState stateUpdate) {
    final stateChanged = _changesState(stateUpdate);
    if (!stateChanged) {
      return;
    }

    final currentConfig = currentConfiguration!;
    _replaceStack(
      DevToolsRouteConfiguration(
        currentConfig.page,
        currentConfig.params,
        currentConfig.state?.merge(stateUpdate) ?? stateUpdate,
      ),
    );
    // Add the new state to the browser history.
    notifyListeners();
  }

  /// Checks whether applying [changes] over the current route's args will result
  /// in any changes.
  bool _changesArgs(Map<String, String?>? changes) {
    final currentConfig = currentConfiguration!;
    return !mapEquals(
      currentConfig.params.withUpdates(changes).params,
      currentConfig.params.params,
    );
  }

  /// Checks whether applying [changes] over the current route's state will result
  /// in any changes.
  bool _changesState(DevToolsNavigationState? changes) {
    final currentState = currentConfiguration!.state;
    if (currentState == null) {
      return changes != null;
    }
    return currentState.hasChanges(changes);
  }
}

/// Encapsulates state associated with a [Router] navigation event.
class DevToolsNavigationState {
  DevToolsNavigationState({
    required this.kind,
    required Map<String, String?> state,
  }) : _state = {
          _kKind: kind,
          ...state,
        };

  DevToolsNavigationState._(this._state) : kind = _state[_kKind]!;

  static const _kKind = '_kind';

  final String kind;

  UnmodifiableMapView<String, String?> get state => UnmodifiableMapView(_state);
  final Map<String, String?> _state;

  bool hasChanges(DevToolsNavigationState? other) {
    return !mapEquals(
      {...state, ...?other?.state},
      state,
    );
  }

  /// Creates a new [DevToolsNavigationState] by merging this instance with
  /// [other].
  ///
  /// State contained in [other] will take precedence over state contained in
  /// this instance (e.g., if both instances have state with the same key, the
  /// state in [other] will be used).
  DevToolsNavigationState merge(DevToolsNavigationState other) {
    final newState = <String, String?>{
      ..._state,
      ...other._state,
    };
    return DevToolsNavigationState(kind: kind, state: newState);
  }

  @override
  String toString() => _state.toString();

  Map<String, dynamic> toJson() => _state;
}

/// Mixin that gives controllers the ability to respond to changes in router
/// navigation state.
mixin RouteStateHandlerMixin on DisposableController {
  DevToolsRouterDelegate? _delegate;

  @override
  void dispose() {
    super.dispose();
    _delegate?.removeListener(_onRouteStateUpdate);
  }

  void subscribeToRouterEvents(DevToolsRouterDelegate delegate) {
    final oldDelegate = _delegate;
    if (oldDelegate != null) {
      oldDelegate.removeListener(_onRouteStateUpdate);
    }
    delegate.addListener(_onRouteStateUpdate);
    _delegate = delegate;
  }

  void _onRouteStateUpdate() {
    final state = _delegate?.currentConfiguration?.state;
    if (state == null) return;
    onRouteStateUpdate(state);
  }

  /// Perform operations based on changes in navigation state.
  ///
  /// This method is only invoked if [subscribeToRouterEvents] has been called on
  /// this instance with a valid [DevToolsRouterDelegate].
  void onRouteStateUpdate(DevToolsNavigationState state);
}
