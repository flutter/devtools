// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../flutter/theme.dart';
import '../../utils.dart';
import 'common.dart';
import 'debugger_controller.dart';

class BreakpointPicker extends StatefulWidget {
  const BreakpointPicker({Key key, @required this.controller})
      : super(key: key);

  final DebuggerController controller;

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
    final subtleStyle =
        TextStyle(color: Theme.of(context).unselectedWidgetColor);

    return Material(
      child: InkWell(
        // todo:
        onTap: () => print(bp),
        child: densePadding(
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('● '),
              Text(_descriptionFor(bp)),
              Expanded(
                child: Text(
                  ' (${bp.scriptUri})',
                  style: subtleStyle,
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
    return Badge(
      child: Text(
        '${nf.format(breakpoints.length)}',
      ),
    );
  }
}

class Badge extends StatelessWidget {
  const Badge({@required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Chip(
        label: child,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(vertical: -4.0),
      ),
    );
  }
}
