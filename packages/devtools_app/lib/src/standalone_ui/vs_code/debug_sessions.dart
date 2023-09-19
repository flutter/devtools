// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/constants.dart';
import '../../shared/screen.dart';
import '../api/vs_code_api.dart';

class DebugSessions extends StatelessWidget {
  const DebugSessions(this.screens, this.api, this.sessions, {super.key});

  final List<Screen> screens;
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
            screens: screens,
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
    required this.screens,
  });

  final VsCodeApi api;
  final VsCodeDebugSession session;
  final bool isFlutter;
  final bool isDebug;
  final bool isProfile;
  final List<Screen> screens;

  @override
  Widget build(BuildContext context) {
    final normalDirection = Directionality.of(context);
    final reversedDirection = normalDirection == TextDirection.ltr
        ? TextDirection.rtl
        : TextDirection.ltr;

    Widget? devToolsButton(Screen screen) {
      // Don't include any screens that aren't appropriate.
      if (!screen.requiresConnection ||
          screen.requiresLibrary != null ||
          screen.requiresVmDeveloperMode ||
          screen.screenId == 'debugger') {
        return null;
      }

      final enabled = (!screen.requiresDartVm || isDebug /* && !isWeb */) &&
          (!screen.requiresDebugBuild || isDebug) &&
          (!screen.requiresFlutter || isFlutter);
      return SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            alignment: Alignment.centerRight,
            shape: const ContinuousRectangleBorder(),
          ),
          onPressed: enabled
              ? () =>
                  unawaited(api.openDevToolsPage(session.id, screen.screenId))
              : null,
          label: Directionality(
            textDirection: normalDirection,
            child: Text(screen.title ?? screen.screenId),
          ),
          icon: Icon(screen.icon, size: actionsIconSize),
        ),
      );
    }

    return Directionality(
      // Reverse the direction so the menu is anchored on the far side and
      // expands in the opposite direction with the icons on the right.
      textDirection: reversedDirection,
      child: MenuAnchor(
        style: const MenuStyle(
          alignment: AlignmentDirectional.bottomStart,
        ),
        // TODO(dantup): Why is appSize etc. still missing?
        menuChildren: screens
            .map((screen) => devToolsButton(screen))
            .whereNotNull()
            .toList(),

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
            Icons.construction,
            size: actionsIconSize,
          ),
        ),
      ),
    );
  }
}
