// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/utils.dart';

import '../shared/globals.dart';

/// Manager for DevTools screen controllers.
///
/// There are two distinct sets of screen controllers:
/// 1. the controllers for connected mode (when DevTools is connected to a live
///    VM service connection).
/// 2. the controllers for offline mode (when DevTools is showing offline data).
///    DevTools may be showing offline data even when DevTools is connected. In
///    this case, DevTools displays this data on another route, and there will
///    be two sets of screen controllers in memory.
///
/// Each set of controllers will have at most one controller per DevTools
/// screen. Each controller is globally accessible from anywhere in DevTools.
class ScreenControllers {
  final _connectedControllers = <Type, _LazyController<DevToolsScreenController>>{};

  final _offlineControllers = <Type, _LazyController<DevToolsScreenController>>{};

  void register<T extends DevToolsScreenController>(
    T Function() controllerCreator, {
    bool offline = false,
  }) {
    final lazyController = _LazyController<T>(creator: controllerCreator);
    if (offline) {
      assert(!_offlineControllers.containsKey(T));
      _offlineControllers[T] = lazyController;
    } else {
      assert(!_connectedControllers.containsKey(T));
      _connectedControllers[T] = lazyController;
    }
  }

  /// Returns the active screen controller of type [T].
  /// 
  /// When DevTools is showing offline data, the offline screen controller will
  /// be returned.
  T lookup<T>() {
    if (offlineDataController.showingOfflineData.value) {
      assert(_offlineControllers.containsKey(T));
      return _offlineControllers[T]!.controller as T;
    } else {
      assert(_connectedControllers.containsKey(T));
      return _connectedControllers[T]!.controller as T;
    }
  }

  void disposeConnectedControllers() {
    for (final lazyController in _connectedControllers.values) {
      lazyController.dispose();
    }
    _connectedControllers.clear();
  }

  void disposeOfflineControllers() {
    for (final lazyController in _offlineControllers.values) {
      lazyController.dispose();
    }
    _offlineControllers.clear();
  }
}

class _LazyController<T extends DevToolsScreenController> {
  _LazyController({required this.creator});

  final T Function() creator;

  /// Lazily create and initialize the controller on the first use.
  T get controller => _controller ??= creator()..init();
  T? _controller;

  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}
