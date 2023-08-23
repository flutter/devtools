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
          ElevatedButton(
            onPressed: () =>
                unawaited(widget.api.executeCommand('flutter.createProject')),
            child: const Text('New Flutter Project'),
          ),
        if (widget.api.capabilities.selectDevice)
          StreamBuilder(
            stream: widget.api.devicesChanged,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }
              final deviceEvent = snapshot.data!;
              return Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  for (final device in deviceEvent.devices)
                    TableRow(
                      children: [
                        TextButton(
                          child: Text(device.name),
                          onPressed: () =>
                              unawaited(widget.api.selectDevice(device.id)),
                        ),
                        Text(
                          device.id == deviceEvent.selectedDeviceId
                              ? '(selected)'
                              : '',
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        if (widget.api.capabilities.executeCommand)
          ElevatedButton(
            onPressed: () =>
                unawaited(widget.api.executeCommand('flutter.doctor')),
            child: const Text('Run Flutter Doctor'),
          ),
      ],
    );
  }
}
