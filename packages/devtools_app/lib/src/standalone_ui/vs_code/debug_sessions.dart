// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/screen.dart';
import '../api/vs_code_api.dart';

class DebugSessions extends StatelessWidget {
  const DebugSessions(this.api, this.sessions, {super.key});

  final VsCodeApi api;
  final List<VsCodeDebugSession> sessions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Debug Sessions',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (sessions.isEmpty)
          const Text('Begin a debug session to use DevTools.')
        else
          Table(
            columnWidths: const {0: FlexColumnWidth()},
            defaultColumnWidth:
                FixedColumnWidth(defaultIconSize + defaultSpacing),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              for (final session in sessions)
                _createSessionRow(context, session),
            ],
          ),
      ],
    );
  }

  TableRow _createSessionRow(BuildContext context, VsCodeDebugSession session) {
    // TODO(dantup): What to show if mode is unknown (null)?
    final name = session.name;
    final mode = session.flutterMode;
    final isDebug = mode == 'debug';
    final isProfile = mode == 'profile';
    // final isRelease = mode == 'release' || mode == 'jit_release';
    final isFlutter = session.debuggerType?.contains('Flutter') ?? false;

    return TableRow(
      children: [
        Text(
          '$name ($mode)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (api.capabilities.openDevToolsPage) ...[
          // TODO(dantup): Make these conditions use the real screen
          //  conditions and/or verify if these conditions are correct.
          _devToolsButton(
            session,
            ScreenMetaData.inspector,
            enabled: isFlutter && isDebug,
          ),
          _devToolsButton(
            session,
            ScreenMetaData.cpuProfiler,
            enabled: isDebug || isProfile,
          ),
          _devToolsButton(
            session,
            ScreenMetaData.memory,
            enabled: isDebug || isProfile,
          ),
          _devToolsButton(
            session,
            ScreenMetaData.performance,
          ),
          _devToolsButton(
            session,
            ScreenMetaData.network,
            enabled: isDebug,
          ),
          _devToolsButton(
            session,
            ScreenMetaData.logging,
          ),
        ],
      ],
    );
  }

  Widget _devToolsButton(
    VsCodeDebugSession session,
    ScreenMetaData screen, {
    bool enabled = true,
  }) {
    return DevToolsTooltip(
      message: screen.title ?? screen.id,
      padding: const EdgeInsets.all(denseSpacing),
      child: TextButton(
        onPressed: enabled
            ? () => unawaited(api.openDevToolsPage(session.id, screen.id))
            : null,
        child: Icon(screen.icon, size: actionsIconSize),
      ),
    );
  }
}
