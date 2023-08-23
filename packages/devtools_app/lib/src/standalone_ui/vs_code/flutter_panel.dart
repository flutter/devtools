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
import 'debug_session_info.dart';
import 'device_selector.dart';

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
    return Column(
      children: [
        const SizedBox(height: defaultSpacing),
        if (widget.api.capabilities.executeCommand)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () => unawaited(
                  widget.api.executeCommand('flutter.createProject'),
                ),
                child: const Text('New Flutter Project'),
              ),
              ElevatedButton(
                onPressed: () => unawaited(
                  widget.api.executeCommand('flutter.doctor'),
                ),
                child: const Text('Run Flutter Doctor'),
              ),
            ],
          ),
        if (widget.api.capabilities.selectDevice)
          StreamBuilder(
            stream: widget.api.devicesChanged,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  const SizedBox(height: defaultSpacing),
                  Text(
                    'Devices',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  DeviceSelector(
                    api: widget.api,
                    deviceInfo: snapshot.data!,
                  ),
                ],
              );
            },
          ),
        const SizedBox(height: defaultSpacing),
        StreamBuilder(
          stream: widget.api.debugSessionsChanged,
          builder: (context, snapshot) {
            final sessions = snapshot.data?.sessions ?? const [];
            return Column(
              children: [
                Text(
                  'Debug Sessions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (sessions.isEmpty)
                  DebugSessionInfo(api: widget.api)
                else
                  for (final session in sessions)
                    DebugSessionInfo(
                      api: widget.api,
                      debugSession: session,
                    ),
              ],
            );
          },
        ),
      ],
    );
  }
}
