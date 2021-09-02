// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import 'auto_dispose_mixin.dart';
import 'common_widgets.dart';
import 'framework/framework_core.dart';
import 'globals.dart';
import 'notifications.dart';
import 'routing.dart';
import 'theme.dart';
import 'url_utils.dart';
import 'utils.dart';

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
    Key key,
    @required this.url,
    @required this.builder,
    this.allowConnectionScreenOnDisconnect = true,
  })  : assert(builder != null),
        super(key: key);

  /// The builder for the widget's children.
  ///
  /// Will only be built if [_InitializerState._checkLoaded] is true.
  final WidgetBuilder builder;

  /// The url to attempt to load a vm service from.
  ///
  /// If null, the app will navigate to the [ConnectScreen].
  final String url;

  /// Whether to allow navigating to the connection screen upon disconnect.
  final bool allowConnectionScreenOnDisconnect;

  @override
  _InitializerState createState() => _InitializerState();
}

class _InitializerState extends State<Initializer>
    with SingleTickerProviderStateMixin, AutoDisposeMixin {
  /// Checks if the [service.serviceManager] is connected.
  ///
  /// This is a method and not a getter to communicate that its value may
  /// change between successive calls.
  bool _checkLoaded() => serviceManager.hasConnection;

  OverlayEntry currentDisconnectedOverlay;

  @override
  void initState() {
    super.initState();

    // If we become disconnected by means other than a manual disconnect action,
    // attempt to reconnect.
    addAutoDisposeListener(serviceManager.connectedState, () {
      final connectionState = serviceManager.connectedState.value;
      if (!connectionState.connected &&
          !connectionState.userInitiatedConnectionState) {
        // Try to reconnect (otherwise, will fall back to showing the
        // disconnected overlay).
        _attemptUrlConnection();
      }
    });

    // Trigger a rebuild when the connection becomes available. This is done
    // by onConnectionAvailable and not onStateChange because we also need
    // to have queried what type of app this is before we load the UI.
    autoDispose(
      serviceManager.onConnectionAvailable.listen((_) => setState(() {})),
    );

    _attemptUrlConnection();
  }

  @override
  void didUpdateWidget(Initializer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle widget rebuild when the URL has changed.
    if (widget.url != null && widget.url != oldWidget.url) {
      _attemptUrlConnection();
    }
  }

  Future<void> _attemptUrlConnection() async {
    if (widget.url == null) {
      _handleNoConnection();
      return;
    }

    final uri = normalizeVmServiceUri(widget.url);
    final connected = await FrameworkCore.initVmService(
      '',
      explicitUri: uri,
      errorReporter: (message, error) =>
          Notifications.of(context).push('$message, $error'),
    );

    if (!connected) {
      _handleNoConnection();
    }
  }

  /// Shows a "disconnected" overlay if the [service.serviceManager] is not currently connected.
  void _handleNoConnection() {
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      if (!_checkLoaded() &&
          ModalRoute.of(context).isCurrent &&
          currentDisconnectedOverlay == null) {
        Overlay.of(context).insert(_createDisconnectedOverlay());

        addAutoDisposeListener(serviceManager.connectedState, () {
          final connectedState = serviceManager.connectedState.value;
          if (connectedState.connected) {
            // Hide the overlay if we become reconnected.
            hideDisconnectedOverlay();
          }
        });
      }
    });
  }

  void hideDisconnectedOverlay() {
    currentDisconnectedOverlay?.remove();
    currentDisconnectedOverlay = null;
  }

  OverlayEntry _createDisconnectedOverlay() {
    final theme = Theme.of(context);
    currentDisconnectedOverlay = OverlayEntry(
      builder: (context) => Container(
        // TODO(dantup): Change this to a theme colour and ensure it works in both dart/light themes
        color: const Color.fromRGBO(128, 128, 128, 0.5),
        child: Center(
          child: Column(
            children: [
              const Spacer(),
              Text('Disconnected', style: theme.textTheme.headline3),
              const SizedBox(height: defaultSpacing),
              if (widget.allowConnectionScreenOnDisconnect)
                ElevatedButton(
                    onPressed: () {
                      hideDisconnectedOverlay();
                      DevToolsRouterDelegate.of(context)
                          .navigate(homePageId, {'uri': null});
                    },
                    child: const Text(connectToNewAppText))
              else
                Text(
                  'Run a new debug session to reconnect',
                  style: theme.textTheme.bodyText2,
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: hideDisconnectedOverlay,
                child: const Text('Review History'),
              ),
              const SizedBox(height: defaultSpacing),
            ],
          ),
        ),
      ),
    );
    return currentDisconnectedOverlay;
  }

  @override
  Widget build(BuildContext context) {
    return _checkLoaded()
        ? widget.builder(context)
        : Scaffold(
            body: currentDisconnectedOverlay != null
                ? const SizedBox()
                : const CenteredCircularProgressIndicator(),
          );
  }
}
