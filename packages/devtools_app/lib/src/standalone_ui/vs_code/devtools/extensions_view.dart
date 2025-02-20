// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter/material.dart';

import '../../../extensions/extension_screen.dart';
import '../../../shared/analytics/analytics.dart' as ga;
import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/editor/api_classes.dart';
import '../../../shared/editor/editor_client.dart';
import 'shared.dart';
import 'sidebar_extensions_controller.dart';

DevToolsButtonData _buttonDataFromExtension(DevToolsExtensionConfig ext) {
  return (
    label: ext.name,
    icon: ext.icon,
    iconAsset: null,
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

class SidebarDevToolsExtensions extends StatefulWidget {
  const SidebarDevToolsExtensions({
    super.key,
    required this.editor,
    required this.debugSessions,
  });

  final EditorClient editor;
  final Map<String, EditorDebugSession> debugSessions;

  @override
  State<SidebarDevToolsExtensions> createState() =>
      _SidebarDevToolsExtensionsState();
}

class _SidebarDevToolsExtensionsState extends State<SidebarDevToolsExtensions>
    with AutoDisposeMixin {
  final sidebarExtensionsController = SidebarDevToolsExtensionsController();

  @override
  void initState() {
    super.initState();
    unawaited(sidebarExtensionsController.initialize(widget.debugSessions));
    addAutoDisposeListener(sidebarExtensionsController.uniqueExtensions);
  }

  @override
  void didUpdateWidget(SidebarDevToolsExtensions oldWidget) {
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
          children: generateRows(widget.editor, extensions),
        ),
      ],
    );
  }

  List<TableRow> generateRows(
    EditorClient editor,
    List<DevToolsExtensionConfig> extensions,
  ) {
    final rows = <TableRow>[];
    for (int i = 0; i < extensions.length; i++) {
      final ext = extensions[i];
      final data = _buttonDataFromExtension(ext);
      rows.add(
        createDevToolsScreenRow(
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
              editor.gaId,
              gac.EditorSidebar.openDevToolsScreen(
                gac.DevToolsExtensionEvents.extensionScreenName(ext),
              ),
            );
            unawaited(
              widget.editor.openDevToolsPage(
                null,
                page: ext.screenId,
                requiresDebugSession: ext.requiresConnection,
                // TODO(https://github.com/flutter/devtools/issues/7955): set
                // the 'prefersDebugSession' value based on the support matrix
                // declared by the extension.
              ),
            );
          },
        ),
      );
    }
    return rows;
  }
}
