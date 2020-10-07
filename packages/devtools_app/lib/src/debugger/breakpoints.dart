// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common_widgets.dart';
import '../theme.dart';
import '../utils.dart';
import 'common.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';

const executableLineRadius = 1.5;
const breakpointRadius = 6.0;

class Breakpoints extends StatefulWidget {
  const Breakpoints({Key key}) : super(key: key);

  @override
  _BreakpointsState createState() => _BreakpointsState();
}

class _BreakpointsState extends State<Breakpoints> {
  DebuggerController controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<DebuggerController>(context);
    if (newController == controller) return;
    controller = newController;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<BreakpointAndSourcePosition>>(
      valueListenable: controller.breakpointsWithLocation,
      builder: (context, breakpoints, _) {
        return ValueListenableBuilder<BreakpointAndSourcePosition>(
          valueListenable: controller.selectedBreakpoint,
          builder: (context, selectedBreakpoint, _) {
            return ListView.builder(
              itemCount: breakpoints.length,
              itemExtent: defaultListItemHeight,
              itemBuilder: (_, index) {
                return buildBreakpoint(
                  breakpoints[index],
                  selectedBreakpoint,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget buildBreakpoint(
    BreakpointAndSourcePosition bp,
    BreakpointAndSourcePosition selectedBreakpoint,
  ) {
    final theme = Theme.of(context);
    final isSelected = bp.id == selectedBreakpoint?.id;

    return Material(
      color: isSelected ? theme.selectedRowColor : null,
      child: InkWell(
        onTap: () => _onBreakpointSelected(bp),
        child: Padding(
          padding: const EdgeInsets.all(borderPadding),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: borderPadding,
                  right: borderPadding * 2,
                ),
                child: createCircleWidget(
                  breakpointRadius,
                  (isSelected
                          ? theme.selectedTextStyle
                          : theme.regularTextStyle)
                      .color,
                ),
              ),
              Flexible(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    text: _descriptionFor(bp),
                    style: isSelected
                        ? theme.selectedTextStyle
                        : theme.regularTextStyle,
                    children: [
                      TextSpan(
                        text: ' (${bp.scriptUri})',
                        style: isSelected
                            ? theme.selectedTextStyle
                            : theme.subtleTextStyle,
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

  void _onBreakpointSelected(BreakpointAndSourcePosition bp) {
    controller.selectBreakpoint(bp);
  }

  String _descriptionFor(BreakpointAndSourcePosition breakpoint) {
    final fileName = breakpoint.scriptUri.split('/').last;

    // Consider showing columns in the future if we allow multiple breakpoints
    // per line.
    return '$fileName:${breakpoint.line}';
  }
}

class BreakpointsCountBadge extends StatelessWidget {
  const BreakpointsCountBadge({@required this.breakpoints});

  final List<BreakpointAndSourcePosition> breakpoints;

  @override
  Widget build(BuildContext context) {
    return Badge('${nf.format(breakpoints.length)}');
  }
}
