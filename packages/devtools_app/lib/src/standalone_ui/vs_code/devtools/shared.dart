// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../service/editor/editor_client.dart';
import '../../../shared/analytics/analytics.dart' as ga;
import '../../../shared/analytics/constants.dart' as gac;

typedef DevToolsButtonData = ({
  String label,
  IconData icon,
  String screenId,
  bool requiresDebugSession,
  bool prefersDebugSession,
});

TableRow createDevToolsScreenRow({
  required DevToolsButtonData dataLeft,
  required DevToolsButtonData? dataRight,
  required bool singleColumn,
  required bool hasDebugSessions,
  required EditorClient editor,
  required void Function(DevToolsButtonData data) onPressed,
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

  final DevToolsButtonData data;
  final EditorClient editor;
  final bool hasDebugSessions;
  final void Function(DevToolsButtonData data) onPressed;

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

void openDevToolsScreen({
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
