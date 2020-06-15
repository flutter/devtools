// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'auto_dispose_mixin.dart';
import 'framework/framework_core.dart';
import 'globals.dart';
import 'inspector/flutter_widget.dart';
import 'notifications.dart';
import 'url_utils.dart';

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

  bool _dependenciesLoaded = false;

  @override
  void initState() {
    super.initState();

    /// Ensure that we loaded the inspector dependencies before attempting to
    /// build the Provider.
    ensureInspectorDependencies().then((_) {
      if (!mounted) return;
      setState(() {
        _dependenciesLoaded = true;
      });
    });

    // If we become disconnected, attempt to reconnect.
    autoDispose(
      serviceManager.onStateChange.where((connected) => !connected).listen((_) {
        // Try to reconnect (otherwise, will fall back to showing the disconnected
        // overlay).
        _attemptUrlConnection();
      }),
    );
    // Trigger a rebuild when the connection becomes available. This is done
    // by onConnectionAvailable and not onStateChange because we also need
    // to have queried what type of app this is before we load the UI.
    autoDispose(
      serviceManager.onConnectionAvailable.listen((_) => setState(() {})),
    );

    _attemptUrlConnection();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_checkLoaded() && ModalRoute.of(context).isCurrent) {
        Overlay.of(context).insert(_createDisconnectedOverlay());
      }
    });
  }

  OverlayEntry _createDisconnectedOverlay() {
    final theme = Theme.of(context);
    OverlayEntry overlay;
    overlay = OverlayEntry(
      builder: (context) => Container(
        // TODO(dantup): Change this to a theme colour and ensure it works in both dart/light themes
        color: const Color.fromRGBO(128, 128, 128, 0.5),
        child: Center(
          child: Column(
            children: [
              const Spacer(),
              Text('Disconnected', style: theme.textTheme.headline3),
              if (widget.allowConnectionScreenOnDisconnect)
                RaisedButton(
                    onPressed: () {
                      overlay.remove();
                      Navigator.of(context).popAndPushNamed(homeRoute);
                    },
                    child: const Text('Connect to Another App'))
              else
                Text(
                  'Run a new debug session to reconnect',
                  style: theme.textTheme.bodyText2,
                ),
              const Spacer(),
              RaisedButton(
                onPressed: () {
                  overlay.remove();
                },
                child: const Text('Review History'),
              ),
            ],
          ),
        ),
      ),
    );
    return overlay;
  }

  @override
  Widget build(BuildContext context) {
    return _checkLoaded() && _dependenciesLoaded
        ? widget.builder(context)
        : const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
  }
}

/// Loads the widgets.json file from Flutter's [rootBundle].
///
/// This will fail if called in a test run with `--platform chrome`.
/// Tests that call this method should be annotated `@TestOn('vm')`.
Future<void> ensureInspectorDependencies() async {
  // TODO(jacobr): move this rootBundle loading code into
  // InspectorController once the dart:html app is removed and Flutter
  // conventions for loading assets can be the default.
  if (Catalog.instance == null) {
    final json = await rootBundle.loadString('web/widgets.json');
    // ignore: invalid_use_of_visible_for_testing_member
    Catalog.setCatalog(Catalog.decode(json));
  }
}
