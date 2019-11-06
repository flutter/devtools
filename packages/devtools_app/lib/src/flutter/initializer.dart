// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../auto_dispose.dart';
import '../framework/framework_core.dart';
import '../globals.dart';
import '../url_utils.dart';
import 'auto_dispose_mixin.dart';
import 'common_widgets.dart';
import 'navigation.dart';

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
  const Initializer({Key key, this.url, @required this.builder})
      : assert(builder != null),
        super(key: key);

  /// The builder for the widget's children.
  ///
  /// Will only be built if [_InitializerState._checkLoaded] is true.
  final WidgetBuilder builder;

  /// The url to attempt to load a vm service from.
  ///
  /// If null, the app will navigate to the [ConnectScreen].
  final String url;

  @override
  _InitializerState createState() => _InitializerState();
}

class _InitializerState extends State<Initializer>
    with SingleTickerProviderStateMixin, AutoDisposeBase, AutoDisposeMixin {
  /// Checks if the [service.serviceManager] is connected.
  ///
  /// This is a method and not a getter to communicate that its value may
  /// change between successive calls.
  bool _checkLoaded() => serviceManager.hasConnection;

  @override
  void initState() {
    super.initState();
    autoDispose(
      serviceManager.onStateChange.listen((_) {
        // Generally, empty setState calls in Flutter should be avoided.
        // However, serviceManager is an implicit part of this state.
        // This setState call is alerting a change in the serviceManager's
        // state.
        setState(() {});
        // TODO(https://github.com/flutter/devtools/issues/1285): On losing
        // the connection, only provide an option to reconnect; don't
        // immediately go to the connection page.
        // If we've become disconnected, attempt to reconnect.
        _navigateToConnectPage();
      }),
    );
    if (widget.url != null) {
      _attemptUrlConnection();
    } else {
      _navigateToConnectPage();
    }
  }

  Future<void> _attemptUrlConnection() async {
    final uri = normalizeVmServiceUri(widget.url);
    final connected = await FrameworkCore.initVmService(
      '',
      explicitUri: uri,
      errorReporter: showErrorSnackBar(context),
    );
    if (!connected) {
      _navigateToConnectPage();
    }
  }

  /// Loads the /connect page if the [service.serviceManager] is not currently connected.
  void _navigateToConnectPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_checkLoaded() && ModalRoute.of(context).isCurrent) {
        // If this route is on top and the app is not loaded, then we navigate to
        // the /connect page to get a VM Service connection for serviceManager.
        // When it completes, the serviceManager will notify this instance.
        Navigator.of(context).pushNamed(
          routeNameWithQueryParams(context, '/connect'),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _checkLoaded()
        ? widget.builder(context)
        : const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
  }
}
