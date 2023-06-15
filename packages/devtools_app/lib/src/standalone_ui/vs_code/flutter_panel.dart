// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../devtools_app.dart';
import '../../shared/feature_flags.dart';
import 'device_info.dart';
import 'temp_api.dart';
import 'web_socket_connection_screen.dart';

/// Panel shown in the VS Code sidebar.
///
/// If [embedded] is `true`, the panel is shown directly. Otherwise, a
/// connection screen is shown asking for a WebSocket URL that can be obtained
/// by running the "Dart: Connect External Sidebar" command in VS Code to run
/// the sidebar outside of VS Code.
class VsCodeFlutterPanel extends StatefulWidget {
  const VsCodeFlutterPanel({required this.embedded, super.key});

  final bool embedded;

  @override
  State<VsCodeFlutterPanel> createState() => _VsCodeFlutterPanelState();
}

class _VsCodeFlutterPanelState extends State<VsCodeFlutterPanel> {
  DartApi? api;

  @override
  void initState() {
    super.initState();

    if (widget.embedded && api == null) {
      api = DartApi.postMessage();
    }
  }

  @override
  void dispose() {
    super.dispose();

    api?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(FeatureFlags.vsCodeSidebarTooling);

    final api = this.api;
    // A null api is only valid if we're not-embedded and haven't connected yet.
    assert(!widget.embedded || api != null);

    return api != null
        ? _MainPanel(api: api)
        : WebSocketConnectionScreen(
            onConnected: (webSocket) {
              setState(() {
                this.api = DartApi.webSocket(webSocket);
              });
            },
          );
  }
}

/// The main panel shown once an API connection is available.
class _MainPanel extends StatelessWidget {
  const _MainPanel({required this.api});

  final DartApi api;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Text('TODO: a panel for flutter actions in VS Code'),
          FutureBuilder(
            future: api.vsCode.isAvailable,
            builder: (context, snapshot) => switch (snapshot.data) {
              true => DeviceInfo(api.vsCode),
              false => const Text('VS Code is unavailable!'),
              null => const CenteredCircularProgressIndicator(),
            },
          ),
        ],
      ),
    );
  }
}
