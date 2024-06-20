// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter/material.dart';

import '../../extensions/extension_screen.dart';
import '../../service/editor/api_classes.dart';
import '../../service/editor/editor_client.dart';
import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/common_widgets.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/screen.dart';
import 'devtools_extensions.dart';

typedef _DevToolsButtonData = ({
  String label,
  IconData icon,
  String screenId,
  bool requiresDebugSession,
  bool prefersDebugSession,
});

_DevToolsButtonData _buttonDataFromScreen(ScreenMetaData screen) {
  final id = screen.title ?? screen.id;
  return (
    label: id,
    icon: screen.icon!,
    screenId: screen.id,
    requiresDebugSession: screen.requiresConnection,
    // Only the app size screen does not care about the active debug session.
    prefersDebugSession: screen != ScreenMetaData.appSize,
  );
}

_DevToolsButtonData _buttonDataFromExtension(DevToolsExtensionConfig ext) {
  return (
    label: ext.name,
    icon: ext.icon,
    screenId: ext.screenId,
    requiresDebugSession: ext.requiresConnection,
    // TODO(https://github.com/flutter/devtools/issues/7955): let extensions
    // declare the type of tool they are providing: 'static-only',
    // 'runtime-only', or 'static-and-runtime'. The value for
    // prefersDebugSession should be true when the state is 'runtime-only' or
    // 'static-and-runtime'.
    prefersDebugSession: true,
  );
}

/// A widget that displays DevTools options, including buttons to open static
/// screens, and a list of static DevTools extensions available for the IDE
/// workspace.
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
    final theme = Theme.of(context);
    // Use a LayoutBuilder instead of checking ScreenSize.of(context) so that
    // this UI can be debugged in the mock editor environment.
    return LayoutBuilder(
      builder: (context, constraints) {
        final singleColumn = constraints.maxWidth <= _useSingleColumnThreshold;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DevTools',
                  style: theme.textTheme.titleMedium,
                ),
                if (editor.supportsOpenDevToolsExternally)
                  ToolbarAction(
                    icon: Icons.open_in_browser_outlined,
                    tooltip: 'Open in browser',
                    onPressed: () {
                      ga.select(
                        gac.VsCodeFlutterSidebar.id,
                        gac.VsCodeFlutterSidebar.openDevToolsExternally.name,
                      );
                      unawaited(
                        editor.openDevToolsPage(null, forceExternal: true),
                      );
                    },
                  ),
              ],
            ),
            Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: singleColumn
                  ? null
                  : const <int, TableColumnWidth>{
                      0: FlexColumnWidth(),
                      1: FlexColumnWidth(),
                    },
              children: generateRows(singleColumn),
            ),
            const SizedBox(height: denseSpacing),
            _DevToolsExtensions(
              editor: editor,
              debugSessions: debugSessions,
            ),
          ],
        );
      },
    );
  }

  List<TableRow> generateRows(bool singleColumn) {
    final devtoolsScreens =
        ScreenMetaData.values.where(includeInSidebar).toList();
    if (singleColumn) {
      return devtoolsScreens
          .map(
            (s) => _createDevToolsScreenRow(
              dataLeft: _buttonDataFromScreen(s),
              dataRight: null,
              editor: editor,
              singleColumn: singleColumn,
              hasDebugSessions: debugSessions.isNotEmpty,
              onPressed: (data) => _openDevToolsScreen(
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
        _createDevToolsScreenRow(
          dataLeft: _buttonDataFromScreen(first),
          dataRight: second != null ? _buttonDataFromScreen(second) : null,
          editor: editor,
          singleColumn: singleColumn,
          hasDebugSessions: debugSessions.isNotEmpty,
          onPressed: (data) => _openDevToolsScreen(
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
      ScreenMetaData.simple =>
        false,
      _ => true,
    };
  }
}

// TODO(kenz): move this to devtools_extensions.dart in a follow up PR.
class _DevToolsExtensions extends StatefulWidget {
  const _DevToolsExtensions({
    required this.editor,
    required this.debugSessions,
  });

  final EditorClient editor;
  final Map<String, EditorDebugSession> debugSessions;

  @override
  State<_DevToolsExtensions> createState() => _DevToolsExtensionsState();
}

class _DevToolsExtensionsState extends State<_DevToolsExtensions>
    with AutoDisposeMixin {
  final sidebarExtensionsController = SidebarDevToolsExtensionsController();

  @override
  void initState() {
    super.initState();
    unawaited(sidebarExtensionsController.init(widget.debugSessions));
    addAutoDisposeListener(sidebarExtensionsController.uniqueExtensions);
  }

  @override
  void didUpdateWidget(_DevToolsExtensions oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(
      sidebarExtensionsController.updateForDebugSessions(widget.debugSessions),
    );
  }

  @override
  void dispose() {
    sidebarExtensionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extensions = sidebarExtensionsController.uniqueExtensions.value;
    if (extensions.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DevTools Extensions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: generateRows(extensions),
        ),
      ],
    );
  }

  List<TableRow> generateRows(List<DevToolsExtensionConfig> extensions) {
    final rows = <TableRow>[];
    for (int i = 0; i < extensions.length; i++) {
      final ext = extensions[i];
      final data = _buttonDataFromExtension(ext);
      rows.add(
        _createDevToolsScreenRow(
          dataLeft: data,
          dataRight: null,
          // Extensions will always be laid out along a single column
          // because we do not have control over how long the names
          // will be and we want to avoid ugly text wrapping.
          singleColumn: true,
          editor: widget.editor,
          hasDebugSessions: widget.debugSessions.isNotEmpty,
          onPressed: (data) {
            ga.select(
              gac.VsCodeFlutterSidebar.id,
              gac.VsCodeFlutterSidebar.openDevToolsScreen(
                gac.DevToolsExtensionEvents.extensionScreenName(ext),
              ),
            );
            unawaited(
              widget.editor.openDevToolsPage(null, page: ext.screenId),
            );
          },
        ),
      );
    }
    return rows;
  }
}

TableRow _createDevToolsScreenRow({
  required _DevToolsButtonData dataLeft,
  required _DevToolsButtonData? dataRight,
  required bool singleColumn,
  required bool hasDebugSessions,
  required EditorClient editor,
  required void Function(_DevToolsButtonData data) onPressed,
}) {
  assert(
    !singleColumn || dataRight == null,
    'dataRight must be null is singleColumn is true',
  );
  final cellRight = dataRight != null
      ? _DevToolsScreenButton(
          data: dataRight,
          editor: editor,
          hasDebugSessions: hasDebugSessions,
          onPressed: onPressed,
        )
      : const SizedBox();
  return TableRow(
    children: [
      _DevToolsScreenButton(
        data: dataLeft,
        editor: editor,
        hasDebugSessions: hasDebugSessions,
        onPressed: onPressed,
      ),
      if (!singleColumn) cellRight,
    ],
  );
}

class _DevToolsScreenButton extends StatelessWidget {
  const _DevToolsScreenButton({
    required this.data,
    required this.editor,
    required this.hasDebugSessions,
    required this.onPressed,
  });

  final _DevToolsButtonData data;
  final EditorClient editor;
  final bool hasDebugSessions;
  final void Function(_DevToolsButtonData data) onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // TODO(kenz): consider also disabling tools based on the available debug
    // sessions. For example, if the only debug session is a Web app, we know
    // some tools are not available.
    final disableButton = data.requiresDebugSession && !hasDebugSessions;
    return SizedBox(
      width: double.infinity,
      child: maybeWrapWithTooltip(
        tooltip:
            disableButton ? 'This tool requires an active debug session' : null,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            shape: const ContinuousRectangleBorder(),
            textStyle: theme.regularTextStyle,
          ),
          icon: Icon(
            data.icon,
            size: actionsIconSize,
            color: theme.colorScheme.onSurface,
          ),
          label: Text(
            data.label,
            style:
                disableButton ? theme.subtleTextStyle : theme.regularTextStyle,
          ),
          onPressed: disableButton ? null : () => onPressed(data),
        ),
      ),
    );
  }
}

void _openDevToolsScreen({
  required String screenId,
  required bool requiresDebugSession,
  required bool prefersDebugSession,
  required EditorClient editor,
}) {
  ga.select(
    gac.VsCodeFlutterSidebar.id,
    gac.VsCodeFlutterSidebar.openDevToolsScreen(screenId),
  );
  unawaited(
    editor.openDevToolsPage(
      null,
      page: screenId,
      requiresDebugSession: requiresDebugSession,
      prefersDebugSession: prefersDebugSession,
    ),
  );
}
