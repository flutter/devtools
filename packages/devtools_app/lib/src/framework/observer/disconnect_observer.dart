// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../framework/framework_core.dart';
import '../../service/connected_app/connection_info.dart';
import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/config_specific/import_export/import_export.dart';
import '../../shared/framework/routing.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/query_parameters.dart';

class DisconnectObserver extends StatefulWidget {
  const DisconnectObserver({
    super.key,
    required this.routerDelegate,
    required this.child,
  });

  final Widget child;
  final DevToolsRouterDelegate routerDelegate;

  @override
  State<DisconnectObserver> createState() => DisconnectObserverState();
}

class DisconnectObserverState extends State<DisconnectObserver>
    with AutoDisposeMixin {
  OverlayEntry? currentDisconnectedOverlay;

  late ConnectedState currentConnectionState;

  /// Stores the last known VM service URI so we can attempt to reconnect
  /// after the connection is lost (e.g. when the machine sleeps).
  String? _lastVmServiceUri;

  bool _isReconnecting = false;

  @override
  void initState() {
    super.initState();

    currentConnectionState =
        serviceConnection.serviceManager.connectedState.value;

    addAutoDisposeListener(serviceConnection.serviceManager.connectedState, () {
      final previousConnectionState = currentConnectionState;
      currentConnectionState =
          serviceConnection.serviceManager.connectedState.value;

      if (currentConnectionState.connected &&
          currentDisconnectedOverlay != null) {
        setState(() {
          hideDisconnectedOverlay();
        });
      } else if (!currentConnectionState.connected) {
        if (previousConnectionState.connected &&
            !currentConnectionState.connected &&
            !currentConnectionState.userInitiatedConnectionState) {
          // We became disconnected by means other than a manual disconnect
          // action, so show the overlay and ensure the 'uri' query parameter
          // has been cleared.
          //
          // Store the VM service URI before clearing so we can attempt
          // reconnection later (e.g. after machine sleep/wake).
          // Fall back to the live service URI if router params are already gone.
          _lastVmServiceUri =
              widget.routerDelegate.currentConfiguration?.params.vmServiceUri ??
              serviceConnection.serviceManager.serviceUri;
          unawaited(widget.routerDelegate.clearUriParameter());
          showDisconnectedOverlay();
        }
      }
    });
  }

  @override
  void dispose() {
    hideDisconnectedOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void showDisconnectedOverlay() {
    if (serviceConnection.serviceManager.connectedState.value.connected ||
        currentDisconnectedOverlay != null) {
      return;
    }
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      ga.select(gac.devToolsMain, gac.appDisconnected);
      Overlay.of(context).insert(_createDisconnectedOverlay());
    });
  }

  void hideDisconnectedOverlay() {
    currentDisconnectedOverlay?.remove();
    currentDisconnectedOverlay = null;
  }

  Future<void> _reviewHistory() async {
    assert(offlineDataController.offlineDataJson.isNotEmpty);

    offlineDataController.startShowingOfflineData(
      offlineApp: offlineDataController.previousConnectedApp!,
    );
    hideDisconnectedOverlay();
    final args = <String, String?>{
      DevToolsQueryParams.vmServiceUriKey: null,
      DevToolsQueryParams.offlineScreenIdKey:
          offlineDataController.offlineDataJson[DevToolsExportKeys
                  .activeScreenId
                  .name]
              as String,
    };
    await widget.routerDelegate.popRoute();
    widget.routerDelegate.navigate(snapshotScreenId, args);
  }

  OverlayEntry _createDisconnectedOverlay() {
    final theme = Theme.of(context);
    currentDisconnectedOverlay = OverlayEntry(
      builder: (context) => Material(
        child: Container(
          color: theme.colorScheme.surface,
          child: Center(
            child: Column(
              children: [
                const Spacer(),
                Text('Disconnected', style: theme.textTheme.headlineMedium),
                const SizedBox(height: defaultSpacing),
                if (_isReconnecting)
                  const CircularProgressIndicator()
                else if (!isEmbedded())
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _attemptReconnect,
                        child: const Text('Reconnect'),
                      ),
                      const SizedBox(width: defaultSpacing),
                      ConnectToNewAppButton(
                        routerDelegate: widget.routerDelegate,
                        onPressed: hideDisconnectedOverlay,
                        gaScreen: gac.devToolsMain,
                      ),
                    ],
                  )
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: _attemptReconnect,
                        child: const Text('Reconnect'),
                      ),
                      const SizedBox(height: defaultSpacing),
                      Text(
                        'Or run a new debug session to reconnect.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                const Spacer(),
                if (offlineDataController.offlineDataJson.isNotEmpty) ...[
                  ElevatedButton(
                    onPressed: _reviewHistory,
                    child: const Text('Review recent data (offline)'),
                  ),
                  const Spacer(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return currentDisconnectedOverlay!;
  }

  Future<void> _attemptReconnect() async {
    setState(() => _isReconnecting = true);
    currentDisconnectedOverlay?.markNeedsBuild();

    try {
      await dtdManager.reconnect();

      final uri = _lastVmServiceUri;
      if (uri != null &&
          !serviceConnection.serviceManager.connectedState.value.connected) {
        // Call initVmService directly — do NOT use routerDelegate.navigate()
        // because that goes through _replaceStack which calls manuallyDisconnect
        // when clearing the URI, causing the disconnect observer to suppress
        // the overlay (userInitiatedConnectionState = true).
        await FrameworkCore.initVmService(
          serviceUriAsString: uri,
          logException: false,
          // Suppress the error notification — we handle failure ourselves below.
          errorReporter: (_, __) {},
        );
      }
    } catch (e) {
      // Swallow errors — we check connected state in finally instead.
    } finally {
      _isReconnecting = false;

      if (serviceConnection.serviceManager.connectedState.value.connected) {
        // Success — also update the router so the URI is reflected in the URL.
        unawaited(
          widget.routerDelegate.updateArgsIfChanged({
            DevToolsQueryParams.vmServiceUriKey: _lastVmServiceUri,
          }),
        );
        setState(() => hideDisconnectedOverlay());
      } else {
        // Failed (stale URI, VM dead, etc.) — restore the overlay with buttons.
        currentDisconnectedOverlay?.markNeedsBuild();
        showDisconnectedOverlay();
      }
    }
  }
}