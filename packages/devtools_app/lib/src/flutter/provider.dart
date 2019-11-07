// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../auto_dispose.dart';
import '../globals.dart';
import '../logging/logging_controller.dart';

/// Container for controlers that should outlive individual screens of the app.
@immutable
class ProviderData implements DisposableController {
  const ProviderData({@required this.loggingController})
      : assert(loggingController != null);

  /// Builds the default providers for the app.
  factory ProviderData.defaultProviders() {
    return ProviderData(
      loggingController: LoggingController(
        onLogCountStatusChanged: (_) {},
        // TODO(djshuckerow): Use a notifier pattern for the logging controller.
        // That way, it is visible if it has listeners and invisible otherwise.
        isVisible: () => true,
      ),
    );
  }

  final LoggingController loggingController;

  @override
  void dispose() {
    loggingController.dispose();
  }
}

/// Provider for controlers that should outlive individual screens of the app.
class Provider extends StatefulWidget {
  const Provider({Key key, this.child, this.overrideProviders})
      : super(key: key);

  final ProviderData Function() overrideProviders;
  final Widget child;

  @override
  _ProviderState createState() => _ProviderState();

  static ProviderData of(BuildContext context) {
    final _InheritedProvider inherited =
        context.inheritFromWidgetOfExactType(_InheritedProvider);
    return inherited.data;
  }
}

class _ProviderState extends State<Provider> {
  ProviderData data;

  @override
  void initState() {
    super.initState();
    // Everything depends on the serviceManager being available.
    assert(serviceManager != null);

    _initializeProviderData();
  }

  @override
  void didUpdateWidget(Provider oldWidget) {
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
      data = ProviderData.defaultProviders();
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

  final ProviderData data;

  @override
  bool updateShouldNotify(_InheritedProvider oldWidget) {
    return oldWidget.data != data;
  }
}
