// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:dtd/dtd.dart';
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
import 'devtools/devtools_view.dart';

/// A general Flutter sidebar panel for embedding inside editors.
///
/// Provides some basic functionality to improve discoverability of features
/// such as creation of new projects, device selection and DevTools features.
class DtdEditorSidebarPanel extends StatefulWidget {
  // TODO(dantup): Remove the Dtd prefix from these classes when the postMessage
  //  versions are removed.
  const DtdEditorSidebarPanel(this.dtd, {super.key});

  final DartToolingDaemon dtd;

  @override
  State<DtdEditorSidebarPanel> createState() => _DtdEditorSidebarPanelState();
}

class _DtdEditorSidebarPanelState extends State<DtdEditorSidebarPanel> {
  _DtdEditorSidebarPanelState();

  Future<EditorClient>? _editor;

  @override
  void initState() {
    super.initState();

    final editor = DtdEditorClient(widget.dtd);
    ga.screen(editor.gaId);
    unawaited(_editor = editor.initialized.then((_) => editor));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: FutureBuilder(
            future: _editor,
            builder: (context, snapshot) =>
                switch ((snapshot.connectionState, snapshot.data)) {
              (ConnectionState.done, final editor?) =>
                _EditorConnectedPanel(editor),
              _ => const CenteredCircularProgressIndicator(),
            },
          ),
        ),
      ],
    );
  }
}

/// A general Flutter sidebar panel for embedding inside postMessage-based
/// editors.
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
    ga.screen(gac.EditorSidebar.legacyId);
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
              _EditorConnectedPanel(PostMessageEditorClient(vsCodeApi)),
            (ConnectionState.done, null) =>
              const Text('VS Code is not available'),
            _ => const CenteredCircularProgressIndicator(),
          },
        ),
      ],
    );
  }
}

/// The panel shown once we know an editor is available.
class _EditorConnectedPanel extends StatefulWidget {
  const _EditorConnectedPanel(this.editor);

  final EditorClient editor;

  @override
  State<_EditorConnectedPanel> createState() => _EditorConnectedPanelState();
}

class _EditorConnectedPanelState extends State<_EditorConnectedPanel>
    with AutoDisposeMixin {
  var debugSessions = <String, EditorDebugSession>{};
  var devices = <String, EditorDevice>{};
  String? selectedDeviceId;

  late final ScrollController scrollController;

  @override
  void initState() {
    super.initState();

    scrollController = ScrollController();

    cancelStreamSubscriptions();
    // Set up subscription to handle events when the available editor services
    // change.
    autoDisposeStreamSubscription(
      widget.editor.editorServiceChanged.listen((info) async {
        // When services appear that allow us to get the initial list, call
        // them.
        if (info is ServiceRegistered) {
          if (info.method == EditorMethod.getDevices.name) {
            await widget.editor.getDevices().then((result) {
              for (final device in result.devices) {
                devices[device.id] = device;
              }
              selectedDeviceId = result.selectedDeviceId;
            });
          } else if (info.method == EditorMethod.getDebugSessions.name) {
            await widget.editor.getDebugSessions().then((result) {
              for (final session in result.debugSessions) {
                debugSessions[session.id] = session;
              }
            });
          }
        }

        // Force an update because editor services changing will impact what
        // we show.
        setState(() {});
      }),
    );
    // Set up handlers to respond to incoming events from the editor.
    autoDisposeStreamSubscription(
      widget.editor.event.listen((event) {
        setState(() {
          switch (event) {
            // Devices.
            case DeviceAddedEvent(:final device):
            case DeviceChangedEvent(:final device):
              devices[device.id] = device;
            case DeviceRemovedEvent(:final deviceId):
              devices.remove(deviceId);
            case DeviceSelectedEvent(:final deviceId):
              selectedDeviceId = deviceId;
            // Debug sessions.
            case DebugSessionStartedEvent(:final debugSession):
            case DebugSessionChangedEvent(:final debugSession):
              debugSessions[debugSession.id] = debugSession;
            case DebugSessionStoppedEvent(:final debugSessionId):
              debugSessions.remove(debugSessionId);
            case ThemeChangedEvent():
            // Do nothing; this is handled in
            // lib/src/framework/theme_manager.dart.
          }
        });
      }),
    );
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: scrollController,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            denseSpacing,
            defaultSpacing,
            defaultSpacing, // Additional right padding for scroll bar.
            defaultSpacing,
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
              if (widget.editor.supportsOpenDevToolsPage)
                DevToolsSidebarOptions(
                  editor: widget.editor,
                  debugSessions: debugSessions,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
