// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../shared/analytics/analytics.dart' as ga;
import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/editor/api_classes.dart';
import '../../../shared/editor/editor_client.dart';
import '../../../shared/framework/screen.dart';
import '../../../shared/primitives/utils.dart';
import '../../../shared/ui/common_widgets.dart';
import 'extensions_view.dart';
import 'shared.dart';

/// A widget that displays DevTools options with buttons to open each DevTools
/// screen or extension.
class DevToolsSidebarOptions extends StatelessWidget {
  const DevToolsSidebarOptions({
    required this.editor,
    required this.debugSessions,
    super.key,
  });

  final EditorClient editor;
  final Map<String, EditorDebugSession> debugSessions;

  static const _useSingleColumnThreshold = 245.0;

  @override
  Widget build(BuildContext context) {
    // Use a LayoutBuilder instead of checking ScreenSize.of(context) so that
    // this UI can be debugged in the mock editor environment.
    return LayoutBuilder(
      builder: (context, constraints) {
        final singleColumn = constraints.maxWidth <= _useSingleColumnThreshold;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SidebarDevToolsScreens(
              editor: editor,
              debugSessions: debugSessions,
              singleColumn: singleColumn,
            ),
            const SizedBox(height: denseSpacing),
            SidebarDevToolsExtensions(
              editor: editor,
              debugSessions: debugSessions,
            ),
          ],
        );
      },
    );
  }
}

class SidebarDevToolsScreens extends StatelessWidget {
  const SidebarDevToolsScreens({
    super.key,
    required this.editor,
    required this.debugSessions,
    required this.singleColumn,
  });

  final EditorClient editor;
  final Map<String, EditorDebugSession> debugSessions;
  final bool singleColumn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('DevTools', style: theme.textTheme.titleMedium),
            if (editor.supportsOpenDevToolsForceExternal)
              ToolbarAction(
                icon: Icons.open_in_browser_outlined,
                tooltip: 'Open in browser',
                onPressed: () {
                  ga.select(
                    editor.gaId,
                    gac.EditorSidebar.openDevToolsExternally.name,
                  );
                  unawaited(editor.openDevToolsPage(null, forceExternal: true));
                },
              ),
          ],
        ),
        Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths:
              singleColumn
                  ? null
                  : const <int, TableColumnWidth>{
                    0: FlexColumnWidth(),
                    1: FlexColumnWidth(),
                  },
          children: generateRows(singleColumn),
        ),
      ],
    );
  }

  List<TableRow> generateRows(bool singleColumn) {
    final devtoolsScreens =
        ScreenMetaData.values.where(includeInSidebar).toList();
    if (singleColumn) {
      return devtoolsScreens
          .map(
            (s) => createDevToolsScreenRow(
              dataLeft: _buttonDataFromScreen(s),
              dataRight: null,
              editor: editor,
              singleColumn: singleColumn,
              hasDebugSessions: debugSessions.isNotEmpty,
              onPressed:
                  (data) => openDevToolsScreen(
                    screenId: data.screenId,
                    requiresDebugSession: data.requiresDebugSession,
                    prefersDebugSession: data.prefersDebugSession,
                    editor: editor,
                  ),
            ),
          )
          .toList();
    }

    final rows = <TableRow>[];
    for (int i = 0; i < devtoolsScreens.length; i += 2) {
      final first = devtoolsScreens[i];
      final second = devtoolsScreens.safeGet(i + 1);
      rows.add(
        createDevToolsScreenRow(
          dataLeft: _buttonDataFromScreen(first),
          dataRight: second != null ? _buttonDataFromScreen(second) : null,
          editor: editor,
          singleColumn: singleColumn,
          hasDebugSessions: debugSessions.isNotEmpty,
          onPressed:
              (data) => openDevToolsScreen(
                screenId: data.screenId,
                requiresDebugSession: data.requiresDebugSession,
                prefersDebugSession: data.prefersDebugSession,
                editor: editor,
              ),
        ),
      );
    }
    return rows;
  }

  DevToolsButtonData _buttonDataFromScreen(ScreenMetaData screen) {
    final id = screen.title ?? screen.id;
    return (
      label: id,
      icon: screen.icon,
      iconAsset: screen.iconAsset,
      screenId: screen.id,
      requiresDebugSession: screen.requiresConnection,
      // Only the app size screen does not care about the active debug session.
      prefersDebugSession: screen != ScreenMetaData.appSize,
    );
  }

  @visibleForTesting
  static bool includeInSidebar(ScreenMetaData screen) {
    return switch (screen) {
      ScreenMetaData.home ||
      ScreenMetaData.debugger ||
      ScreenMetaData.vmTools ||
      // This screen will be removed from the first party DevTools screens soon.
      // If the user depends on package:provider, the provider extension should
      // show up in the DevTools extensions list instead.
      ScreenMetaData.provider ||
      ScreenMetaData.simple => false,
      _ => true,
    };
  }
}
