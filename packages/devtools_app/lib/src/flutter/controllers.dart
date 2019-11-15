// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../auto_dispose.dart';
import '../globals.dart';
import '../logging/logging_controller.dart';
import '../timeline/timeline_controller.dart';

/// Container for controllers that should outlive individual screens of the app.
///
/// Note that [dispose] should only be called when nothing will be using this
/// particular [ProvidedControllers] instance again.
@immutable
class ProvidedControllers implements DisposableController {
  const ProvidedControllers({@required this.logging, @required this.timeline})
      : assert(logging != null),
        assert(timeline != null);

  /// Builds the default providers for the app.
  factory ProvidedControllers.defaults() {
    return ProvidedControllers(
      logging: LoggingController(
        onLogCountStatusChanged: (_) {},
        // TODO(djshuckerow): Use a notifier pattern for the logging controller.
        // That way, it is visible if it has listeners and invisible otherwise.
        isVisible: () => true,
      ),
      timeline: TimelineController(),
    );
  }

  final LoggingController logging;
  final TimelineController timeline;

  @override
  void dispose() {
    logging.dispose();
    // TODO(kenz): make timeline controller disposable.
  }
}

/// Provider for controllers that should outlive individual screens of the app.
///
/// [Initializer] builds a [Controllers] after it has a connection to the VM
/// service and it has loaded [ensureInspectorDependencies].
class Controllers extends StatefulWidget {
  const Controllers({Key key, Widget child})
      : this._(key: key, child: child, overrideProviders: null);

  @visibleForTesting
  const Controllers.overridden({Key key, this.child, this.overrideProviders});

  const Controllers._({Key key, this.child, this.overrideProviders})
      : super(key: key);

  /// Callback that overrides [ProvidedControllers.defaults].
  @visibleForTesting
  final ProvidedControllers Function() overrideProviders;

  final Widget child;

  @override
  _ControllersState createState() => _ControllersState();

  static ProvidedControllers of(BuildContext context) {
    final _InheritedProvider inherited =
        context.inheritFromWidgetOfExactType(_InheritedProvider);
    return inherited.data;
  }
}

class _ControllersState extends State<Controllers> {
  ProvidedControllers data;

  @override
  void initState() {
    super.initState();
    // Everything depends on the serviceManager being available.
    assert(serviceManager != null);

    _initializeProviderData();
  }

  @override
  void didUpdateWidget(Controllers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.overrideProviders != widget.overrideProviders) {
      _initializeProviderData();
    }
  }

  void _initializeProviderData() {
    if (widget.overrideProviders != null) {
      final dataOverride = widget.overrideProviders();
      assert(
        dataOverride != null,
        'Attempted to build overridden providers, but got a null value.',
      );
      // Dispose the old data only if it's different from the new data.
      // This avoids issues where a provider is returning the same instance
      // each time it's called.
      if (data != dataOverride) {
        data?.dispose();
        data = dataOverride;
      }
    } else {
      data?.dispose();
      data = ProvidedControllers.defaults();
    }
  }

  @override
  void dispose() {
    data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedProvider(data: data, child: widget.child);
  }
}

class _InheritedProvider extends InheritedWidget {
  const _InheritedProvider({@required this.data, @required Widget child})
      : super(child: child);

  final ProvidedControllers data;

  @override
  bool updateShouldNotify(_InheritedProvider oldWidget) {
    return oldWidget.data != data;
  }
}
