// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../shared/analytics/analytics.dart' as ga;
import '../shared/analytics/constants.dart' as gac;
import '../shared/common_widgets.dart';
import '../shared/config_specific/import_export/import_export.dart';
import '../shared/framework_controller.dart';
import '../shared/globals.dart';
import '../shared/primitives/utils.dart';
import '../shared/routing.dart';
import '../shared/ui/colors.dart';
import 'framework_core.dart';

final _log = Logger('initializer');

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
    Key? key,
    required this.url,
    required this.builder,
    this.allowConnectionScreenOnDisconnect = true,
  }) : super(key: key);

  /// The builder for the widget's children.
  ///
  /// Will only be built if [_InitializerState._checkLoaded] is true.
  final WidgetBuilder builder;

  /// The url to attempt to load a vm service from.
  ///
  /// If null, the app will navigate to the [ConnectScreen].
  final String? url;

  /// Whether to allow navigating to the connection screen upon disconnect.
  final bool allowConnectionScreenOnDisconnect;

  @override
  State<Initializer> createState() => _InitializerState();
}

class _InitializerState extends State<Initializer>
    with SingleTickerProviderStateMixin, AutoDisposeMixin {
  /// Checks if the [service.serviceManager] is connected.
  ///
  /// This is a method and not a getter to communicate that its value may
  /// change between successive calls.
  bool _checkLoaded() => serviceConnection.serviceManager.hasConnection;

  OverlayEntry? currentDisconnectedOverlay;

  @override
  void initState() {
    super.initState();

    autoDisposeStreamSubscription(
      frameworkController.onConnectVmEvent.listen(_connectVm),
    );

    // If we become disconnected by means other than a manual disconnect action,
    // attempt to reconnect.
    addAutoDisposeListener(serviceConnection.serviceManager.connectedState, () {
      final connectionState =
          serviceConnection.serviceManager.connectedState.value;
      if (connectionState.connected) {
        setState(() {});
      } else if (!connectionState.userInitiatedConnectionState) {
        // Try to reconnect (otherwise, will fall back to showing the
        // disconnected overlay).
        unawaited(
          _attemptUrlConnection(
            logException: false,
            errorReporter: (_, __) {
              _log.warning(
                'Attempted to reconnect to the application, but failed.',
              );
            },
          ),
        );
      }
    });

    unawaited(_attemptUrlConnection());
  }

  @override
  void didUpdateWidget(Initializer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle widget rebuild when the URL has changed.
    if (widget.url != null && widget.url != oldWidget.url) {
      unawaited(_attemptUrlConnection());
    }
  }

  /// Connects to the VM with the given URI. This request usually comes from the
  /// IDE via the server API to reuse the DevTools window after being disconnected
  /// (for example if the user stops a debug session then launches a new one).
  void _connectVm(ConnectVmEvent event) {
    DevToolsRouterDelegate.of(context).updateArgsIfChanged({
      'uri': event.serviceProtocolUri.toString(),
      if (event.notify) 'notify': 'true',
    });
  }

  Future<void> _attemptUrlConnection({
    ErrorReporter? errorReporter,
    bool logException = true,
  }) async {
    if (widget.url == null) {
      _handleNoConnection();
      return;
    }

    final connected = await FrameworkCore.initVmService(
      serviceUriAsString: widget.url!,
      errorReporter: errorReporter,
      logException: logException,
    );

    if (!connected) {
      _handleNoConnection();
    }
  }

  /// Shows a "disconnected" overlay if the [service.serviceManager] is not currently connected.
  void _handleNoConnection() {
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      if (!_checkLoaded() &&
          ModalRoute.of(context)!.isCurrent &&
          currentDisconnectedOverlay == null) {
        ga.select(
          gac.devToolsMain,
          gac.appDisconnected,
        );
        Overlay.of(context).insert(_createDisconnectedOverlay());

        addAutoDisposeListener(
          serviceConnection.serviceManager.connectedState,
          () {
            final connectedState =
                serviceConnection.serviceManager.connectedState.value;
            if (connectedState.connected) {
              // Hide the overlay if we become reconnected.
              hideDisconnectedOverlay();
            }
          },
        );
      }
    });
  }

  void hideDisconnectedOverlay() {
    setState(() {
      currentDisconnectedOverlay?.remove();
      currentDisconnectedOverlay = null;
    });
  }

  void _reviewHistory() {
    assert(offlineController.offlineDataJson.isNotEmpty);

    offlineController.enterOfflineMode(
      offlineApp: offlineController.previousConnectedApp!,
    );
    hideDisconnectedOverlay();
    final args = <String, String?>{
      'uri': null,
      'screen': offlineController
          .offlineDataJson[DevToolsExportKeys.activeScreenId.name] as String,
    };
    final routerDelegate = DevToolsRouterDelegate.of(context);
    Router.neglect(
      context,
      () => routerDelegate.navigate(snapshotScreenId, args),
    );
  }

  OverlayEntry _createDisconnectedOverlay() {
    final theme = Theme.of(context);
    currentDisconnectedOverlay = OverlayEntry(
      builder: (context) => Container(
        color: theme.colorScheme.overlayShadowColor,
        child: Center(
          child: Column(
            children: [
              const Spacer(),
              Text('Disconnected', style: theme.textTheme.displaySmall),
              const SizedBox(height: defaultSpacing),
              if (widget.allowConnectionScreenOnDisconnect)
                ElevatedButton(
                  onPressed: () {
                    hideDisconnectedOverlay();
                    DevToolsRouterDelegate.of(context).navigateHome(
                      clearUriParam: true,
                      clearScreenParam: true,
                    );
                  },
                  child: const Text(connectToNewAppText),
                )
              else
                Text(
                  'Run a new debug session to reconnect',
                  style: theme.textTheme.bodyMedium,
                ),
              const Spacer(),
              if (offlineController.offlineDataJson.isNotEmpty)
                ElevatedButton(
                  onPressed: _reviewHistory,
                  child: const Text('Review recent data (offline)'),
                ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
    return currentDisconnectedOverlay!;
  }

  @override
  Widget build(BuildContext context) {
    return _checkLoaded() || offlineController.offlineMode.value
        ? widget.builder(context)
        : Scaffold(
            body: currentDisconnectedOverlay != null
                ? const SizedBox()
                : const CenteredCircularProgressIndicator(),
          );
  }
}
