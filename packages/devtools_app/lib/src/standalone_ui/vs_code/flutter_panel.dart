// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/common_widgets.dart';
import '../api/dart_tooling_api.dart';
import '../api/vs_code_api.dart';
import 'debug_sessions.dart';
import 'devices.dart';
import 'devtools.dart';

/// A general Flutter sidebar panel for embedding inside IDEs.
///
/// Provides some basic functionality to improve discoverability of features
/// such as creation of new projects, device selection and DevTools features.
class VsCodeFlutterPanel extends StatefulWidget {
  const VsCodeFlutterPanel(this.api, {super.key});

  final DartToolingApi api;

  @override
  State<VsCodeFlutterPanel> createState() => _VsCodeFlutterPanelState();
}

class _VsCodeFlutterPanelState extends State<VsCodeFlutterPanel> {
  @override
  void initState() {
    super.initState();
    ga.screen(gac.VsCodeFlutterSidebar.id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FutureBuilder(
          future: widget.api.vsCode,
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
      padding: const EdgeInsets.symmetric(
        horizontal: denseSpacing,
        vertical: defaultSpacing,
      ),
      // Debug sessions rely on devices too, because they look up the sessions
      // device for some capabilities (for example to know if the session is
      // running on a web device).
      child: StreamBuilder(
        stream: widget.api.devicesChanged,
        builder: (context, devicesSnapshot) {
          final devices = devicesSnapshot.data?.devices ?? const [];
          final unsupportedDevices =
              devicesSnapshot.data?.unsupportedDevices ?? const [];
          final deviceMap = {for (final device in devices) device.id: device};
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder(
                stream: widget.api.debugSessionsChanged,
                builder: (context, debugSessionsSnapshot) {
                  final sessions =
                      debugSessionsSnapshot.data?.sessions ?? const [];
                  return DebugSessions(
                    api: widget.api,
                    sessions: sessions,
                    deviceMap: deviceMap,
                  );
                },
              ),
              const SizedBox(height: defaultSpacing),
              if (widget.api.capabilities.selectDevice) ...[
                Devices(
                  widget.api,
                  devices: devices,
                  unsupportedDevices: unsupportedDevices,
                  selectedDeviceId: devicesSnapshot.data?.selectedDeviceId,
                ),
                const SizedBox(height: denseSpacing),
              ],
              DevToolsSidebarOptions(api: widget.api),
            ],
          );
        },
      ),
    );
  }
}
