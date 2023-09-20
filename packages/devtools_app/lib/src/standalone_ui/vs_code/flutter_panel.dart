// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../devtools_app.dart';
import '../../shared/feature_flags.dart';
import '../api/dart_tooling_api.dart';
import '../api/vs_code_api.dart';
import 'debug_sessions.dart';
import 'devices.dart';

/// A general Flutter sidebar panel for embedding inside IDEs.
///
/// Provides some basic functionality to improve discoverability of features
/// such as creation of new projects, device selection and DevTools features.
class VsCodeFlutterPanel extends StatelessWidget {
  const VsCodeFlutterPanel(this.api, {super.key});

  final DartToolingApi api;

  @override
  Widget build(BuildContext context) {
    assert(FeatureFlags.vsCodeSidebarTooling);

    return Column(
      children: [
        FutureBuilder(
          future: api.vsCode,
          builder: (context, snapshot) =>
              switch ((snapshot.connectionState, snapshot.data)) {
            (ConnectionState.done, final vsCodeApi?) =>
              _VsCodeConnectedPanel(vsCodeApi),
            (ConnectionState.done, null) =>
              const Text('VS Code is not available'),
            _ => const CenteredCircularProgressIndicator(),
          },
        ),
      ],
    );
  }
}

/// The panel shown once we know VS Code is available (the host has responded to
/// the `vsCode.getCapabilities` request).
class _VsCodeConnectedPanel extends StatefulWidget {
  const _VsCodeConnectedPanel(this.api);

  final VsCodeApi api;

  @override
  State<_VsCodeConnectedPanel> createState() => _VsCodeConnectedPanelState();
}

class _VsCodeConnectedPanelState extends State<_VsCodeConnectedPanel> {
  @override
  void initState() {
    super.initState();

    unawaited(widget.api.initialize());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(denseSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: defaultSpacing),
          StreamBuilder(
            stream: widget.api.debugSessionsChanged,
            builder: (context, snapshot) {
              final sessions = snapshot.data?.sessions ?? const [];
              return DebugSessions(widget.api, sessions);
            },
          ),
          const SizedBox(height: defaultSpacing),
          if (widget.api.capabilities.selectDevice)
            StreamBuilder(
              stream: widget.api.devicesChanged,
              builder: (context, snapshot) {
                final devices = snapshot.data?.devices ?? const [];
                final selectedDeviceId = snapshot.data?.selectedDeviceId;
                return Devices(
                  widget.api,
                  devices,
                  selectedDeviceId: selectedDeviceId,
                );
              },
            ),
        ],
      ),
    );
  }
}
