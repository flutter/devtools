// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../shared/common_widgets.dart';
import '../shared/framework_controller.dart';
import '../shared/globals.dart';
import '../shared/routing.dart';

// TODO(kenz): see if we can simplify this widget. Several things have changed
// with DevTools routing and service management code since this widget was
// originally written.

/// Widget that requires business logic to be loaded before building its
/// [builder].
///
/// See [_InitializerState.build] for the logic that determines whether the
/// business logic is loaded.
///
/// Use this widget to wrap pages that require [service.serviceManager] to be
/// connected. As we require additional services to be available, add them
/// here.
class Initializer extends StatefulWidget {
  const Initializer({
    super.key,
    required this.builder,
  });

  /// The builder for the widget's children.
  ///
  /// Will only be built when a connection to an app is established.
  final WidgetBuilder builder;

  @override
  State<Initializer> createState() => _InitializerState();
}

class _InitializerState extends State<Initializer>
    with SingleTickerProviderStateMixin, AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    autoDisposeStreamSubscription(
      frameworkController.onConnectVmEvent.listen(_connectVm),
    );
  }

  /// Connects to the VM with the given URI.
  ///
  /// This request usually comes from the IDE via the server API to reuse the
  /// DevTools window after being disconnected (for example if the user stops
  /// a debug session then launches a new one).
  void _connectVm(ConnectVmEvent event) {
    DevToolsRouterDelegate.of(context).updateArgsIfChanged({
      'uri': event.serviceProtocolUri.toString(),
      if (event.notify) 'notify': 'true',
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: serviceConnection.serviceManager.connectedState,
      builder: (context, connectedState, _) {
        if (connectedState.connected ||
            offlineDataController.showingOfflineData.value) {
          return widget.builder(context);
        }
        return const CenteredMessage('Waiting for VM service connection...');
      },
    );
  }
}
