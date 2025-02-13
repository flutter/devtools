// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../service/connected_app/connection_info.dart';
import '../shared/analytics/constants.dart' as gac;
import '../shared/framework/routing.dart';
import '../shared/globals.dart';
import '../shared/ui/common_widgets.dart';

// TODO(kenz): see if we can simplify this widget. Several things have changed
// with DevTools routing and service management code since this widget was
// originally written.

/// Widget that requires business logic to be loaded before building its
/// [builder].
///
/// See [_InitializerState.build] for the logic that determines whether the
/// business logic is loaded.
///
/// Use this widget to wrap pages that require `service.serviceManager` to be
/// connected. As we require additional services to be available, add them
/// here.
class Initializer extends StatefulWidget {
  const Initializer({super.key, required this.builder});

  /// The builder for the widget's children.
  ///
  /// Will only be built when a connection to an app is established.
  final WidgetBuilder builder;

  @override
  State<Initializer> createState() => _InitializerState();
}

class _InitializerState extends State<Initializer>
    with SingleTickerProviderStateMixin, AutoDisposeMixin {
  static const _waitForConnectionTimeout = Duration(seconds: 2);

  Timer? _timer;

  bool _showConnectToNewAppButton = false;

  @override
  void initState() {
    super.initState();

    _timer = Timer(_waitForConnectionTimeout, () {
      setState(() {
        _showConnectToNewAppButton = true;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
        // TODO(kenz): this should be more sophisticated logic.
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Spacer(),
            CenteredMessage(
              message:
                  _showConnectToNewAppButton
                      ? 'Cannot connect to VM service.'
                      : 'Waiting for VM service connection...',
            ),
            if (_showConnectToNewAppButton) ...[
              const SizedBox(height: defaultSpacing),
              ConnectToNewAppButton(
                routerDelegate: DevToolsRouterDelegate.of(context),
                gaScreen: gac.devToolsMain,
              ),
            ],
            const Spacer(),
          ],
        );
      },
    );
  }
}
