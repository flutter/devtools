// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../service/editor/api_classes.dart';
import '../../service/editor/editor_client.dart';
import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/common_widgets.dart';
import '../api/dart_tooling_api.dart';
import '../api/impl/dart_tooling_api.dart';
import 'debug_sessions.dart';
import 'devices.dart';
import 'devtools.dart';

/// A general Flutter sidebar panel for embedding inside IDEs.
///
/// Provides some basic functionality to improve discoverability of features
/// such as creation of new projects, device selection and DevTools features.
class VsCodePostMessageSidebarPanel extends StatefulWidget {
  const VsCodePostMessageSidebarPanel(this.api, {super.key});

  final PostMessageToolApi api;

  @override
  State<VsCodePostMessageSidebarPanel> createState() =>
      _VsCodePostMessageSidebarPanelState();
}

class _VsCodePostMessageSidebarPanelState
    extends State<VsCodePostMessageSidebarPanel> {
  @override
  void initState() {
    super.initState();
    ga.screen(gac.VsCodeFlutterSidebar.id);
  }

  @override
  void dispose() {
    widget.api.dispose();
    super.dispose();
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
              _VsCodeConnectedPanel(PostMessageEditorClient(vsCodeApi)),
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
  const _VsCodeConnectedPanel(this.editor);

  final EditorClient editor;

  @override
  State<_VsCodeConnectedPanel> createState() => _VsCodeConnectedPanelState();
}

class _VsCodeConnectedPanelState extends State<_VsCodeConnectedPanel>
    with AutoDisposeMixin {
  var debugSessions = <String, EditorDebugSession>{};
  var devices = <String, EditorDevice>{};
  String? selectedDeviceId;

  @override
  void initState() {
    super.initState();

    cancelStreamSubscriptions();
    // Set up subscription to handle events when things change.
    autoDisposeStreamSubscription(
      widget.editor.event.listen((event) {
        setState(() {
          switch (event) {
            // Devices.
            case DeviceAddedEvent(:final device):
              devices[device.id] = device;
            case DeviceChangedEvent(:final device):
              devices[device.id] = device;
            case DeviceRemovedEvent(:final deviceId):
              devices.remove(deviceId);
            case DeviceSelectedEvent(:final deviceId):
              selectedDeviceId = deviceId;
            // Debug sessions.
            case DebugSessionStartedEvent(:final debugSession):
              debugSessions[debugSession.id] = debugSession;
            case DebugSessionChangedEvent(:final debugSession):
              debugSessions[debugSession.id] = debugSession;
            case DebugSessionStoppedEvent(:final debugSessionId):
              debugSessions.remove(debugSessionId);
          }
        });
      }),
    );
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DebugSessions(
            editor: widget.editor,
            sessions: debugSessions,
            devices: devices,
          ),
          const SizedBox(height: defaultSpacing),
          if (widget.editor.supportsSelectDevice) ...[
            Devices(
              editor: widget.editor,
              devices: devices,
              selectedDeviceId: selectedDeviceId,
            ),
            const SizedBox(height: denseSpacing),
          ],
          DevToolsSidebarOptions(
            editor: widget.editor,
            hasDebugSessions: debugSessions.isNotEmpty,
          ),
        ],
      ),
    );
  }
}
