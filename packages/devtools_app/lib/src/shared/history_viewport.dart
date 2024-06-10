// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../screens/debugger/common.dart';
import 'common_widgets.dart';
import 'primitives/history_manager.dart';

/// A [Widget] that allows for displaying content based on the current state of a
/// [HistoryManager]. Includes built-in controls for navigating back and forth
/// through the content stored in the provided [HistoryManager].
///
/// [history] is the [HistoryManager] that contains the data to be displayed.
///
/// [contentBuilder] is invoked with the currently selected historical data
/// when building the contents of the viewport.
///
/// If [controls] is provided, each [Widget] will be inserted with padding
/// at the end of the viewport title bar.
///
/// If [generateTitle] is provided, the title string will be set to the
/// returned value. If not provided, the title will be empty.
class HistoryViewport<T> extends StatefulWidget {
  const HistoryViewport({
    super.key,
    required this.history,
    required this.contentBuilder,
    this.controls,
    this.generateTitle,
    this.onChange,
    this.historyEnabled = true,
    this.onTitleTap,
    this.titleIcon,
  });

  final HistoryManager<T> history;
  final Widget Function(BuildContext, T?) contentBuilder;
  final List<Widget>? controls;
  final String Function(T?)? generateTitle;
  final void Function(T?, T?)? onChange;
  final bool historyEnabled;
  final VoidCallback? onTitleTap;
  final IconData? titleIcon;

  @override
  State<HistoryViewport<T>> createState() => _HistoryViewportState<T>();
}

class _HistoryViewportState<T> extends State<HistoryViewport<T>> {
  TextStyle? _titleStyle;
  Color? _iconColor;

  void _updateTitleStyle(TextStyle style) {
    setState(() {
      _titleStyle = style;
      _iconColor = style.color;
    });
  }

  @override
  Widget build(BuildContext context) {
    final titleIcon = widget.titleIcon != null
        ? Padding(
            padding: const EdgeInsets.only(right: densePadding),
            child: Icon(
              widget.titleIcon,
              size: defaultIconSize,
              color: _iconColor,
            ),
          )
        : const SizedBox.shrink();

    return ValueListenableBuilder<T?>(
      valueListenable: widget.history.current,
      builder: (context, T? current, _) {
        final theme = Theme.of(context);
        final title = widget.generateTitle == null
            ? '  '
            : widget.generateTitle!(current);
        final defaultTitleStyle = theme.textTheme.titleMedium!;
        final titleWidget = debuggerSectionTitle(
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
                          final current = widget.history.current.value as T;
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
                    ? Row(
                        children: [
                          titleIcon,
                          Text(
                            title,
                            style: defaultTitleStyle,
                          ),
                        ],
                      )
                    : MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onExit: (_) {
                          _updateTitleStyle(defaultTitleStyle);
                        },
                        onEnter: (_) {
                          _updateTitleStyle(
                            defaultTitleStyle.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          );
                        },
                        child: GestureDetector(
                          onTap: widget.onTitleTap,
                          child: Row(
                            children: [
                              titleIcon,
                              Expanded(
                                child: Text(
                                  title,
                                  style: _titleStyle ??
                                      theme.textTheme.titleMedium,
                                ),
                              ),
                            ],
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
        return RoundedOutlinedBorder(
          child: Column(
            children: [
              titleWidget,
              widget.contentBuilder(context, current),
            ],
          ),
        );
      },
    );
  }
}
