// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../flutter/common_widgets.dart';
import '../../flutter/theme.dart';
import '../../utils.dart';
import 'common.dart';
import 'debugger_controller.dart';

const executableLineRadius = 1.5;
const breakpointRadius = 6.0;

class BreakpointPicker extends StatefulWidget {
  const BreakpointPicker({
    Key key,
    @required this.controller,
    @required this.selected,
    @required this.onSelected,
  }) : super(key: key);

  final DebuggerController controller;
  final BreakpointAndSourcePosition selected;
  final void Function(BreakpointAndSourcePosition breakpoint) onSelected;

  @override
  _BreakpointPickerState createState() => _BreakpointPickerState();
}

class _BreakpointPickerState extends State<BreakpointPicker> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<BreakpointAndSourcePosition>>(
      valueListenable: widget.controller.breakpointsWithLocation,
      builder: (context, breakpoints, _) {
        return ListView.builder(
          itemCount: breakpoints.length,
          itemExtent: defaultListItemHeight,
          itemBuilder: (context, index) {
            return buildBreakpoint(context, breakpoints[index]);
          },
        );
      },
    );
  }

  Widget buildBreakpoint(BuildContext context, BreakpointAndSourcePosition bp) {
    final theme = Theme.of(context);

    final regularStyle = TextStyle(color: theme.textTheme.bodyText2.color);
    final subtleStyle = TextStyle(color: theme.unselectedWidgetColor);
    final selectedStyle = TextStyle(color: theme.textSelectionColor);

    final isSelected = bp.id == widget.selected?.id;

    return Material(
      color: isSelected ? theme.selectedRowColor : null,
      child: InkWell(
        onTap: () => widget.onSelected(bp),
        child: Padding(
          padding: const EdgeInsets.all(borderPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: borderPadding,
                  right: borderPadding * 2,
                ),
                child: createCircleWidget(
                  breakpointRadius,
                  (isSelected ? selectedStyle : regularStyle).color,
                ),
              ),
              Flexible(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    text: _descriptionFor(bp),
                    style: isSelected ? selectedStyle : regularStyle,
                    children: [
                      TextSpan(
                        text: ' (${bp.scriptUri})',
                        style: isSelected ? selectedStyle : subtleStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _descriptionFor(BreakpointAndSourcePosition breakpoint) {
    final fileName = breakpoint.scriptUri.split('/').last;
    final line = breakpoint.line;

    return breakpoint.resolved
        ? '$fileName:$line:${breakpoint.column}'
        : '$fileName:$line';
  }
}

class BreakpointsCountBadge extends StatelessWidget {
  const BreakpointsCountBadge({@required this.breakpoints});

  final List<Breakpoint> breakpoints;

  @override
  Widget build(BuildContext context) {
    return Badge('${nf.format(breakpoints.length)}');
  }
}
