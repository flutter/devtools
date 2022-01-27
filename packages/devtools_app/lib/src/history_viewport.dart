// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'shared/common_widgets.dart';
import 'debugger/common.dart';
import 'history_manager.dart';
import 'theme.dart';

/// A [Widget] that allows for displaying content based on the current state of a
/// [HistoryManager]. Includes built-in controls for navigating back and forth
/// through the content stored in the provided [HistoryManager].
///
/// [history] is the [HistoryManger] that contains the data to be displayed.
///
/// [contentBuilder] is invoked with the currently selected historical data
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
    @required this.contentBuilder,
    this.controls,
    this.generateTitle,
    this.onChange,
    this.historyEnabled = true,
  });

  final HistoryManager<T> history;
  final String Function(T) generateTitle;
  final List<Widget> controls;
  final Widget Function(BuildContext, T) contentBuilder;
  final void Function(T, T) onChange;
  final bool historyEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlineDecoration(
      child: ValueListenableBuilder(
        valueListenable: history.current,
        builder: (context, current, _) {
          return Column(
            children: [
              _buildTitle(context, theme),
              contentBuilder(context, current),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTitle(BuildContext context, ThemeData theme) {
    return debuggerSectionTitle(
      theme,
      child: Row(
        children: [
          if (historyEnabled) ...[
            ToolbarAction(
              icon: Icons.chevron_left,
              onPressed: history.hasPrevious
                  ? () {
                      history.moveBack();
                      if (onChange != null) {
                        onChange(
                          history.current.value,
                          history.peekNext(),
                        );
                      }
                    }
                  : null,
            ),
            ToolbarAction(
              icon: Icons.chevron_right,
              onPressed: history.hasNext
                  ? () {
                      final current = history.current.value;
                      history.moveForward();
                      if (onChange != null) {
                        onChange(
                          history.current.value,
                          current,
                        );
                      }
                    }
                  : null,
            ),
            const SizedBox(width: denseSpacing),
            const VerticalDivider(thickness: 1.0),
            const SizedBox(width: defaultSpacing),
          ],
          Expanded(
            child: Text(
              generateTitle == null
                  ? '  '
                  : generateTitle(history.current.value),
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
  }
}
