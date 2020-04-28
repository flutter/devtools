// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../../config_specific/logger/logger.dart';
import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/common_widgets.dart';
import '../../flutter/flutter_widgets/linked_scroll_controller.dart';
import '../../flutter/theme.dart';
import '../../ui/theme.dart';
import '../../utils.dart';
import 'breakpoints.dart';
import 'common.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';

// TODO(kenz): consider moving lines / pausedPositions calculations to the
// controller.
class CodeView extends StatefulWidget {
  const CodeView({
    Key key,
    this.controller,
    this.scriptRef,
    this.onSelected,
  }) : super(key: key);

  static const rowHeight = 20.0;
  static const assumedCharacterWidth = 16.0;

  final DebuggerController controller;
  final ScriptRef scriptRef;

  final void Function(ScriptRef scriptRef, int line) onSelected;

  @override
  _CodeViewState createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> with AutoDisposeMixin {
  Script script;
  List<String> lines = [];
  Set<int> executableLines = {};

  LinkedScrollControllerGroup verticalController;
  ScrollController gutterController;
  ScrollController textController;

  ScriptRef get scriptRef => widget.scriptRef;

  @override
  void initState() {
    super.initState();

    _initScriptInfo();

    verticalController = LinkedScrollControllerGroup();
    gutterController = verticalController.addAndGet();
    textController = verticalController.addAndGet();

    addAutoDisposeListener(
        widget.controller.scriptLocation, _handleScriptLocationChanged);
  }

  @override
  void didUpdateWidget(CodeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      cancel();

      addAutoDisposeListener(
          widget.controller.scriptLocation, _handleScriptLocationChanged);
    }

    if (widget.scriptRef != oldWidget.scriptRef) {
      _initScriptInfo();
    }
  }

  @override
  void dispose() {
    super.dispose();

    gutterController.dispose();
    textController.dispose();
  }

  void _initScriptInfo() {
    script = widget.controller.getScriptCached(scriptRef);

    if (script == null) {
      if (scriptRef != null) {
        final scriptId = scriptRef.id;
        widget.controller.getScript(scriptRef).then((script) {
          if (mounted && scriptId == scriptRef.id) {
            setState(() {
              this.script = script;

              _parseScriptLines();
            });
          }
        });
      }
    } else {
      _parseScriptLines();
    }
  }

  void _parseScriptLines() {
    lines = script.source?.split('\n') ?? [];

    // TODO(devoncarew): Change to using SourceReportRange.possibleBreakpoints.
    // (see getSourceReport('PossibleBreakpoints').
    executableLines = {};
    // Recalculate the executable lines.
    if (script.tokenPosTable != null) {
      for (var encodedInfo in script.tokenPosTable) {
        executableLines.add(encodedInfo[0]);
      }
    }
  }

  void _handleScriptLocationChanged() {
    if (mounted) {
      _updateScrollPosition();
    }
  }

  void _updateScrollPosition({bool animate = true}) {
    if (widget.controller.scriptLocation.value.scriptRef != scriptRef) {
      return;
    }

    final location = widget.controller.scriptLocation.value?.location;
    if (location?.line == null) {
      return;
    }

    if (!verticalController.hasAttachedControllers) {
      // TODO(devoncarew): I'm uncertain why this occurs.
      // todo: ???
      log('LinkedScrollControllerGroup has no attached controllers');
      return;
    }

    final position = verticalController.position;
    final extent = position.extentInside;

    // TODO(devoncarew): Adjust this so we don't scroll if we're already in the
    // middle third of the screen.
    if (lines.length * CodeView.rowHeight > extent) {
      // Scroll to the middle of the screen.
      final lineIndex = location.line - 1;
      final scrollPosition =
          lineIndex * CodeView.rowHeight - (extent - CodeView.rowHeight) / 2;
      if (animate) {
        verticalController.animateTo(
          scrollPosition,
          duration: rapidDuration,
          curve: defaultCurve,
        );
      } else {
        verticalController.jumpTo(scrollPosition);
      }
    }
  }

  void _onPressed(int line) {
    widget.onSelected(scriptRef, line);
  }

  @override
  Widget build(BuildContext context) {
    // TODO(#1648): Implement syntax highlighting.
    final theme = Theme.of(context);

    if (scriptRef == null) {
      return Center(
        child: Text(
          'No script selected',
          style: theme.textTheme.subtitle1,
        ),
      );
    }

    if (script == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return buildCodeArea(context);
  }

  Widget buildCodeArea(BuildContext context) {
    final theme = Theme.of(context);

    // Apply the log change-of-base formula, then add 16dp padding for every
    // digit in the maximum number of lines.
    final gutterWidth = CodeView.assumedCharacterWidth * 1.5 +
        CodeView.assumedCharacterWidth *
            (defaultEpsilon + math.log(math.max(lines.length, 100)) / math.ln10)
                .truncateToDouble();

    _updateScrollPosition(animate: false);

    return OutlinedBorder(
      child: Column(
        children: [
          debuggerSectionTitle(theme, text: scriptRef?.uri ?? ' '),
          DefaultTextStyle(
            style: theme.textTheme.bodyText2.copyWith(fontFamily: 'RobotoMono'),
            child: Expanded(
              child: Scrollbar(
                child: ValueListenableBuilder(
                  valueListenable: widget.controller.selectedStackFrame,
                  builder: (context, frame, _) {
                    final pausedLine = frame == null
                        ? null
                        : (frame.scriptRef == scriptRef ? frame.line : null);

                    return Row(
                      children: [
                        ValueListenableBuilder<
                            List<BreakpointAndSourcePosition>>(
                          valueListenable:
                              widget.controller.breakpointsWithLocation,
                          builder: (context, breakpoints, _) {
                            return Gutter(
                              gutterWidth: gutterWidth,
                              scrollController: gutterController,
                              lineCount: lines.length,
                              pausedLine: pausedLine,
                              breakpoints: breakpoints
                                  .where((bp) => bp.scriptRef == scriptRef)
                                  .toList(),
                              executableLines: executableLines,
                              onPressed: _onPressed,
                            );
                          },
                        ),
                        const SizedBox(width: denseSpacing),
                        Expanded(
                          child: Lines(
                            textController: textController,
                            lines: lines,
                            pausedLine: pausedLine,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef IntCallback = void Function(int value);

class Gutter extends StatelessWidget {
  const Gutter({
    @required this.gutterWidth,
    @required this.scrollController,
    @required this.lineCount,
    @required this.pausedLine,
    @required this.breakpoints,
    @required this.executableLines,
    @required this.onPressed,
  });

  final double gutterWidth;
  final ScrollController scrollController;
  final int lineCount;
  final int pausedLine;
  final List<BreakpointAndSourcePosition> breakpoints;
  final Set<int> executableLines;
  final IntCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bpLineSet = Set.from(breakpoints.map((bp) => bp.line));

    return SizedBox(
      width: gutterWidth,
      child: ListView.builder(
        controller: scrollController,
        itemExtent: CodeView.rowHeight,
        itemCount: lineCount,
        itemBuilder: (context, index) {
          final lineNum = index + 1;
          return GutterItem(
            lineNumber: lineNum,
            onPressed: () => onPressed(lineNum),
            isBreakpoint: bpLineSet.contains(lineNum),
            isExecutable: executableLines.contains(lineNum),
            isPausedHere: pausedLine == lineNum,
          );
        },
      ),
    );
  }
}

class GutterItem extends StatelessWidget {
  const GutterItem({
    Key key,
    @required this.lineNumber,
    @required this.isBreakpoint,
    @required this.isExecutable,
    @required this.isPausedHere,
    @required this.onPressed,
  }) : super(key: key);

  final int lineNumber;

  final bool isBreakpoint;

  final bool isExecutable;

  /// Whether the execution point is currently paused here.
  final bool isPausedHere;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final foregroundColor =
        isDarkTheme ? theme.textTheme.bodyText2.color : theme.primaryColor;
    final subtleColor = theme.unselectedWidgetColor;

    const bpBoxSize = 12.0;
    const executionPointIndent = 10.0;

    return InkWell(
      onTap: onPressed,
      child: Container(
        height: CodeView.rowHeight,
        padding: const EdgeInsets.only(right: 4.0),
        decoration: BoxDecoration(color: titleSolidBackgroundColor),
        child: Stack(
          alignment: AlignmentDirectional.centerStart,
          fit: StackFit.expand,
          children: [
            if (isExecutable || isBreakpoint)
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: bpBoxSize,
                  height: bpBoxSize,
                  child: Center(
                    child: createAnimatedCircleWidget(
                      isBreakpoint ? breakpointRadius : executableLineRadius,
                      isBreakpoint ? foregroundColor : subtleColor,
                    ),
                  ),
                ),
              ),
            Text('$lineNumber', textAlign: TextAlign.end),
            Container(
              padding: const EdgeInsets.only(left: executionPointIndent),
              alignment: Alignment.centerLeft,
              child: AnimatedOpacity(
                duration: defaultDuration,
                curve: defaultCurve,
                opacity: isPausedHere ? 1.0 : 0.0,
                child: Icon(
                  Icons.label,
                  size: defaultIconSize,
                  color: foregroundColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Lines extends StatelessWidget {
  const Lines({
    Key key,
    @required this.textController,
    @required this.lines,
    @required this.pausedLine,
  }) : super(key: key);

  final ScrollController textController;
  final List<String> lines;
  final int pausedLine;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: textController,
      itemExtent: CodeView.rowHeight,
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final lineNum = index + 1;
        return LineItem(
          lineContents: lines[index],
          isPausedHere: pausedLine == lineNum,
        );
      },
    );
  }
}

class LineItem extends StatelessWidget {
  const LineItem({
    Key key,
    @required this.lineContents,
    @required this.isPausedHere,
  }) : super(key: key);

  final String lineContents;
  final bool isPausedHere;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final regularStyle = TextStyle(color: theme.textTheme.bodyText2.color);
    final selectedStyle = TextStyle(color: theme.textSelectionColor);

    return Container(
      alignment: Alignment.centerLeft,
      height: CodeView.rowHeight,
      color: isPausedHere ? theme.selectedRowColor : null,
      child: Text(
        lineContents,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isPausedHere ? selectedStyle : regularStyle,
      ),
    );
  }
}
