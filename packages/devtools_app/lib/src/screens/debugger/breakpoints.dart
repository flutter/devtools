// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart' hide Badge;

import '../../shared/globals.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/ui/common_widgets.dart';
import 'common.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';

double get executableLineRadius => scaleByFontFactor(1.5);
double get breakpointRadius => scaleByFontFactor(6.0);

class Breakpoints extends StatelessWidget {
  const Breakpoints({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = screenControllers.lookup<DebuggerController>();
    return MultiValueListenableBuilder(
      listenables: [
        breakpointManager.breakpointsWithLocation,
        controller.selectedBreakpoint,
      ],
      builder: (context, values, _) {
        final breakpoints = values.first as List<BreakpointAndSourcePosition>;
        final selectedBreakpoint =
            values.second as BreakpointAndSourcePosition?;
        return ListView.builder(
          itemCount: breakpoints.length,
          itemExtent: defaultListItemHeight,
          itemBuilder: (_, index) {
            return _Breakpoint(
              breakpoint: breakpoints[index],
              selectedBreakpoint: selectedBreakpoint,
            );
          },
        );
      },
    );
  }
}

class _Breakpoint extends StatelessWidget {
  const _Breakpoint({
    required this.breakpoint,
    required this.selectedBreakpoint,
  });

  final BreakpointAndSourcePosition breakpoint;
  final BreakpointAndSourcePosition? selectedBreakpoint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = breakpoint.id == selectedBreakpoint?.id;
    final controller = screenControllers.lookup<DebuggerController>();

    return Material(
      color: isSelected ? theme.colorScheme.selectedRowBackgroundColor : null,
      child: InkWell(
        onTap: () async => await controller.selectBreakpoint(breakpoint),
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
                  theme.colorScheme.primary,
                ),
              ),
              Flexible(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    text: _descriptionFor(breakpoint),
                    style: theme.regularTextStyle,
                    children: [
                      TextSpan(
                        text: ' (${breakpoint.scriptUri})',
                        style:
                            isSelected
                                ? theme.selectedSubtleTextStyle
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

  String _descriptionFor(BreakpointAndSourcePosition breakpoint) {
    final scriptUri = breakpoint.scriptUri;
    final fileName = scriptUri == null ? 'file' : fileNameFromUri(scriptUri);
    // Consider showing columns in the future if we allow multiple breakpoints
    // per line.
    return '$fileName:${breakpoint.line}';
  }
}

class BreakpointsCountBadge extends StatelessWidget {
  const BreakpointsCountBadge({super.key, required this.breakpoints});

  final List<BreakpointAndSourcePosition> breakpoints;

  @override
  Widget build(BuildContext context) {
    return Badge(nf.format(breakpoints.length));
  }
}
