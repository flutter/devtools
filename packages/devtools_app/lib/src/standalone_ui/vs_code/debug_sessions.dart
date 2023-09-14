// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/constants.dart';
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
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (sessions.isEmpty)
          const Text('Begin a debug session to use DevTools.')
        else
          Table(
            columnWidths: const {
              0: FlexColumnWidth(),
            },
            defaultColumnWidth:
                FixedColumnWidth(actionsIconSize + denseSpacing),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              for (final session in sessions)
                _debugSessionRow(session, context),
            ],
          ),
      ],
    );
  }

  TableRow _debugSessionRow(VsCodeDebugSession session, BuildContext context) {
    // TODO(dantup): What to show if mode is unknown (null)?
    final mode = session.flutterMode;
    final isDebug = mode == 'debug';
    final isProfile = mode == 'profile';
    // final isRelease = mode == 'release' || mode == 'jit_release';
    final isFlutter = session.debuggerType?.contains('Flutter') ?? false;

    return TableRow(
      children: [
        Text(
          '${session.name} (${session.flutterMode})',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        IconButton(
          onPressed: api.capabilities.hotReload && (isDebug || !isFlutter)
              ? () => unawaited(api.hotReload(session.id))
              : null,
          tooltip: 'Hot Reload',
          icon: Icon(hotReloadIcon, size: actionsIconSize),
        ),
        IconButton(
          onPressed: api.capabilities.hotRestart && (isDebug || !isFlutter)
              ? () => unawaited(api.hotRestart(session.id))
              : null,
          tooltip: 'Hot Restart',
          icon: Icon(hotRestartIcon, size: actionsIconSize),
        ),
        if (api.capabilities.openDevToolsPage)
          _DevToolsMenu(
            api: api,
            session: session,
            isFlutter: isFlutter,
            isDebug: isDebug,
            isProfile: isProfile,
          ),
      ],
    );
  }
}

class _DevToolsMenu extends StatelessWidget {
  const _DevToolsMenu({
    required this.api,
    required this.session,
    required this.isFlutter,
    required this.isDebug,
    required this.isProfile,
  });

  final VsCodeApi api;
  final VsCodeDebugSession session;
  final bool isFlutter;
  final bool isDebug;
  final bool isProfile;

  @override
  Widget build(BuildContext context) {
    final normalDirection = Directionality.of(context);
    final reversedDirection = normalDirection == TextDirection.ltr
        ? TextDirection.rtl
        : TextDirection.ltr;

    Widget devToolsButton(
      ScreenMetaData screen, {
      bool enabled = true,
    }) {
      return SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            alignment: Alignment.centerRight,
            shape: const ContinuousRectangleBorder(),
          ),
          onPressed: enabled
              ? () => unawaited(api.openDevToolsPage(session.id, screen.id))
              : null,
          label: Directionality(
            textDirection: normalDirection,
            child: Text(screen.title ?? screen.id),
          ),
          icon: Icon(screen.icon, size: actionsIconSize),
        ),
      );
    }

    return Directionality(
      textDirection: reversedDirection,
      child: MenuAnchor(
        // TODO(dantup): How to flip the menu to be anchored from the right
        //  and expand to the left?
        style: const MenuStyle(
          alignment: AlignmentDirectional.bottomStart,
        ),
        alignmentOffset: const Offset(2, 0),
        menuChildren: [
          // TODO(dantup): Ensure the order matches the DevTools tab bar (if
          //  possible, share this order).
          // TODO(dantup): Make these conditions use the real screen
          //  conditions and/or verify if these conditions are correct.
          devToolsButton(
            ScreenMetaData.inspector,
            enabled: isFlutter && isDebug,
          ),
          devToolsButton(
            ScreenMetaData.cpuProfiler,
            enabled: isDebug || isProfile,
          ),
          devToolsButton(
            ScreenMetaData.memory,
            enabled: isDebug || isProfile,
          ),
          devToolsButton(
            ScreenMetaData.performance,
          ),
          devToolsButton(
            ScreenMetaData.network,
            enabled: isDebug,
          ),
          devToolsButton(
            ScreenMetaData.logging,
          ),
          // TODO(dantup): Check other screens (like appSize) work embedded and
          //  add here.
        ],
        builder: (context, controller, child) => IconButton(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          tooltip: 'DevTools',
          // TODO(dantup): Icon for DevTools menu?
          icon: Icon(
            Icons.developer_mode,
            size: actionsIconSize,
          ),
        ),
      ),
    );
  }
}
