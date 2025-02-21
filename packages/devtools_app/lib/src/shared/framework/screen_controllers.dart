// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/utils.dart';
import 'package:meta/meta.dart';

import '../globals.dart';

/// Manager for DevTools screen controllers.
///
/// There are two distinct sets of screen controllers:
/// 1. the controllers used for interaction with DevTools in standard mode (not
///    showing offline data). A VM service connection may or may not be present.
/// 2. the controllers for offline mode (when DevTools is showing offline data).
///    DevTools may be showing offline data even when DevTools is connected. In
///    this case, DevTools displays this data on another route, and there will
///    be two sets of screen controllers in memory.
///
/// Each set of controllers will have at most one controller per DevTools
/// screen. Each controller is globally accessible from anywhere in DevTools via
/// the [screenControllers] global variable.
class ScreenControllers {
  @visibleForTesting
  final controllers = <Type, _LazyController<DevToolsScreenController>>{};

  @visibleForTesting
  final offlineControllers =
      <Type, _LazyController<DevToolsScreenController>>{};

  /// Registers a DevTools screen controller and stores the value.
  ///
  /// If there is an existing controller of type `T`, the existing controller
  /// will be disposed and removed from the set of stored controllers.
  ///
  /// [controllerCreator] is a callback that will be computed lazily when the
  /// controller is first accessed via [ScreenControllers.lookup].
  ///
  /// [offline] determines whether this controller is being registered for
  /// viewing offline data or for a live VM service connection.
  void register<T extends DevToolsScreenController>(
    T Function() controllerCreator, {
    bool offline = false,
  }) {
    final controllers = offline ? offlineControllers : this.controllers;
    if (controllers.containsKey(T)) {
      controllers.remove(T)?.dispose();
    }
    controllers[T] = _LazyController<T>(creator: controllerCreator);
  }

  /// Returns the active screen controller of type [T].
  ///
  /// When DevTools is showing offline data, the offline screen controller will
  /// be returned.
  T lookup<T>() {
    final controllers =
        offlineDataController.showingOfflineData.value
            ? offlineControllers
            : this.controllers;
    assert(controllers.containsKey(T));
    return controllers[T]!.controller as T;
  }

  /// Disposes all controllers for the current VM service connection.
  ///
  /// This method is called when DevTools disconnects from a VM service
  /// instance.
  void disposeConnectedControllers() {
    for (final lazyController in controllers.values) {
      lazyController.dispose();
    }
    controllers.clear();
  }

  /// Disposes all controllers for the current offline data.
  ///
  /// This method is called when DevTools exits offline mode.
  void disposeOfflineControllers() {
    for (final lazyController in offlineControllers.values) {
      lazyController.dispose();
    }
    offlineControllers.clear();
  }
}

/// Helper class that performs lazy initialization for
/// [DevToolsScreenController]s.
class _LazyController<T extends DevToolsScreenController> {
  _LazyController({required this.creator});

  /// Callback that creates the controller upon the first access.
  final T Function() creator;

  /// Lazily create and initialize the controller on the first use.
  T get controller => _controller ??= creator()..init();
  T? _controller;

  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}

/// Base class for all DevTools screen controllers.
abstract class DevToolsScreenController extends DisposableController {}
