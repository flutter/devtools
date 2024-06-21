// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../service/editor/api_classes.dart';
import '../../service/editor/editor_client.dart';
import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/constants.dart';

class DebugSessions extends StatelessWidget {
  const DebugSessions({
    required this.editor,
    required this.sessions,
    required this.devices,
    super.key,
  });

  final EditorClient editor;

  /// A map of debug session IDs to their debug sessions.
  final Map<String, EditorDebugSession> sessions;

  /// A map of device IDs to their devices.
  final Map<String, EditorDevice> devices;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Debug Sessions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: borderPadding),
            child: Text('No debug sessions'),
          )
        else
          Table(
            columnWidths: const {
              0: FlexColumnWidth(),
            },
            defaultColumnWidth:
                FixedColumnWidth(actionsIconSize + denseSpacing),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              for (final session in sessions.values)
                _debugSessionRow(session, context),
            ],
          ),
      ],
    );
  }

  TableRow _debugSessionRow(EditorDebugSession session, BuildContext context) {
    final mode = session.flutterMode;
    final isDebug = mode == 'debug';
    final isFlutter = session.debuggerType?.contains('Flutter') ?? false;

    final label = session.flutterMode != null
        ? '${session.name} (${session.flutterMode})'
        : session.name;

    return TableRow(
      children: [
        Text(
          label,
          style: Theme.of(context).regularTextStyle,
        ),
        IconButton(
          onPressed: editor.supportsHotReload && (isDebug || !isFlutter)
              ? () {
                  ga.select(
                    gac.VsCodeFlutterSidebar.id,
                    gac.hotReload,
                  );
                  unawaited(editor.hotReload(session.id));
                }
              : null,
          tooltip: 'Hot Reload',
          icon: Icon(hotReloadIcon, size: actionsIconSize),
        ),
        IconButton(
          onPressed: editor.supportsHotRestart && (isDebug || !isFlutter)
              ? () {
                  ga.select(
                    gac.VsCodeFlutterSidebar.id,
                    gac.hotRestart,
                  );
                  unawaited(editor.hotRestart(session.id));
                }
              : null,
          tooltip: 'Hot Restart',
          icon: Icon(hotRestartIcon, size: actionsIconSize),
        ),
      ],
    );
  }
}
