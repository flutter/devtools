// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../primitives/history_manager.dart';
import '../screens/debugger/common.dart';
import 'common_widgets.dart';
import 'theme.dart';

/// A [Widget] that allows for displaying content based on the current state of a
/// [HistoryManager]. Includes built-in control for navigating back and forth
/// through the content stored in the provided [HistoryManager].
///
/// [history] is the [HistoryManger] that contains the data to be displayed.
///
/// [contentBuilder] is invoked with the currently selected historical data
/// when building the contents of the viewport.
///
/// If [control] is provided, each [Widget] will be inserted with padding
/// at the end of the viewport title bar.
///
/// If [generateTitle] is provided, the title string will be set to the
/// returned value. If not provided, the title will be empty.
class HistoryViewport<T> extends StatefulWidget {
  const HistoryViewport({
    required this.history,
    required this.contentBuilder,
    this.controls,
    this.generateTitle,
    this.onChange,
    this.historyEnabled = true,
    this.onTitleTap,
  });

  final HistoryManager<T> history;
  final Widget Function(BuildContext, T?) contentBuilder;
  final List<Widget>? controls;
  final String Function(T?)? generateTitle;
  final void Function(T?, T?)? onChange;
  final bool historyEnabled;
  final VoidCallback? onTitleTap;

  @override
  State<HistoryViewport<T>> createState() => _HistoryViewportState<T>();
}

class _HistoryViewportState<T> extends State<HistoryViewport<T>> {
  TextStyle? _titleStyle;

  void _updateTitleStyle(TextStyle style) {
    setState(() {
      _titleStyle = style;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlineDecoration(
      child: ValueListenableBuilder<T?>(
        valueListenable: widget.history.current,
        builder: (context, T? current, _) {
          return Column(
            children: [
              _buildTitle(context, theme),
              widget.contentBuilder(context, current),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTitle(BuildContext context, ThemeData theme) {
    final title = widget.generateTitle == null
        ? '  '
        : widget.generateTitle!(widget.history.current.value);
    final defaultTitleStyle = theme.textTheme.subtitle2 ?? const TextStyle();
    return debuggerSectionTitle(
      theme,
      child: Row(
        children: [
          if (widget.historyEnabled) ...[
            ToolbarAction(
              icon: Icons.chevron_left,
              onPressed: widget.history.hasPrevious
                  ? () {
                      widget.history.moveBack();
                      if (widget.onChange != null) {
                        widget.onChange!(
                          widget.history.current.value,
                          widget.history.peekNext(),
                        );
                      }
                    }
                  : null,
            ),
            ToolbarAction(
              icon: Icons.chevron_right,
              onPressed: widget.history.hasNext
                  ? () {
                      final current = widget.history.current.value!;
                      widget.history.moveForward();
                      if (widget.onChange != null) {
                        widget.onChange!(
                          widget.history.current.value,
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
            child: widget.onTitleTap == null
                ? Text(
                    title,
                    style: defaultTitleStyle,
                  )
                : MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onExit: (_) => _updateTitleStyle(defaultTitleStyle),
                    onEnter: (_) {
                      _updateTitleStyle(
                        defaultTitleStyle.copyWith(
                          color: theme.colorScheme.devtoolsLink,
                        ),
                      );
                    },
                    child: GestureDetector(
                      onTap: widget.onTitleTap,
                      child: Text(
                        title,
                        style: _titleStyle ?? theme.textTheme.subtitle2,
                      ),
                    ),
                  ),
          ),
          if (widget.controls != null) ...[
            const SizedBox(width: denseSpacing),
            for (final widget in widget.controls!) ...[
              widget,
              const SizedBox(width: denseSpacing),
            ],
          ],
        ],
      ),
    );
  }
}
