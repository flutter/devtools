// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'common_widgets.dart';
import 'debugger/common.dart';
import 'history_manager.dart';
import 'theme.dart';

/// A [Widget] that allows for displaying content based on the current state of a
/// [HistoryManager]. Includes built-in controls for navigating back and forth
/// through the content stored in the provided [HistoryManager].
///
/// [history] is the [HistoryManger] that contains the data to be displayed.
///
/// [buildContents] is invoked with the currently selected historical data
/// when building the contents of the viewport.
///
/// If [controls] is provided, each [Widget] will be inserted with padding
/// at the end of the viewport title bar.
///
/// If [generateTitle] is provided, the title string will be set to the
/// returned value. If not provided, the title will be empty.
class HistoryViewport<T> extends StatelessWidget {
  const HistoryViewport({
    @required this.history,
    @required this.buildContents,
    this.controls,
    this.generateTitle,
  });

  final HistoryManager<T> history;
  final String Function(T) generateTitle;
  final List<Widget> controls;
  final Widget Function(BuildContext, T) buildContents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlineDecoration(
      child: Column(
        children: [
          _buildTitle(context, theme),
          ValueListenableBuilder(
              valueListenable: history.current,
              builder: (context, current, _) {
                return buildContents(context, current);
              }),
        ],
      ),
    );
  }

  Widget _buildTitle(BuildContext context, ThemeData theme) {
    return ValueListenableBuilder(
      valueListenable: history.current,
      builder: (context, history, _) {
        return debuggerSectionTitle(
          theme,
          child: Row(
            children: [
              ToolbarAction(
                icon: Icons.chevron_left,
                onPressed: history.hasPrevious ? history.moveBack : null,
              ),
              ToolbarAction(
                icon: Icons.chevron_right,
                onPressed: history.hasNext ? history.moveForward : null,
              ),
              const SizedBox(width: denseSpacing),
              const VerticalDivider(thickness: 1.0),
              const SizedBox(width: defaultSpacing),
              Expanded(
                child: Text(
                  generateTitle == null ? '  ' : generateTitle(history.current),
                  style: theme.textTheme.subtitle2,
                ),
              ),
              if (controls != null) ...[
                const SizedBox(width: denseSpacing),
                for (final widget in controls) ...[
                  widget,
                  const SizedBox(width: denseSpacing),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}
