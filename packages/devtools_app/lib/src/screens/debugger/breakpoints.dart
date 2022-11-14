// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart' hide Badge;

import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import 'common.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';

double get executableLineRadius => scaleByFontFactor(1.5);
double get breakpointRadius => scaleByFontFactor(6.0);

class Breakpoints extends StatefulWidget {
  const Breakpoints({Key? key}) : super(key: key);

  @override
  _BreakpointsState createState() => _BreakpointsState();
}

class _BreakpointsState extends State<Breakpoints>
    with ProvidedControllerMixin<DebuggerController, Breakpoints> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initController();
  }

  @override
  Widget build(BuildContext context) {
    return DualValueListenableBuilder<List<BreakpointAndSourcePosition>,
        BreakpointAndSourcePosition?>(
      firstListenable: breakpointManager.breakpointsWithLocation,
      secondListenable: controller.selectedBreakpoint,
      builder: (context, breakpoints, selectedBreakpoint, _) {
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
  }

  Widget buildBreakpoint(
    BreakpointAndSourcePosition bp,
    BreakpointAndSourcePosition? selectedBreakpoint,
  ) {
    final theme = Theme.of(context);
    final isSelected = bp.id == selectedBreakpoint?.id;

    return Material(
      color: isSelected ? theme.colorScheme.selectedRowColor : null,
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
    final scriptUri = breakpoint.scriptUri;
    final fileName = scriptUri == null ? 'file' : scriptUri.split('/').last;
    // Consider showing columns in the future if we allow multiple breakpoints
    // per line.
    return '$fileName:${breakpoint.line}';
  }
}

class BreakpointsCountBadge extends StatelessWidget {
  const BreakpointsCountBadge({required this.breakpoints});

  final List<BreakpointAndSourcePosition> breakpoints;

  @override
  Widget build(BuildContext context) {
    return Badge('${nf.format(breakpoints.length)}');
  }
}
