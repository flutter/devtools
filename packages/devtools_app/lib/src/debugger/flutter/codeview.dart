// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' hide Stack;
import 'package:vm_service/vm_service.dart' as vm show Stack;

import '../../flutter/flutter_widgets/linked_scroll_controller.dart';
import '../../flutter/theme.dart';
import 'breakpoints.dart';
import 'common.dart';
import 'debugger_controller.dart';

// TODO(kenz): consider moving lines / pausedPositions calculations to the
// controller.
class CodeView extends StatefulWidget {
  const CodeView({
    Key key,
    this.script,
    this.stack,
    this.controller,
    this.onSelected,
    this.lineNumberToBreakpoint,
  }) : super(key: key);

  static const rowHeight = 20.0;
  static const assumedCharacterWidth = 16.0;

  final DebuggerController controller;
  final Map<int, Breakpoint> lineNumberToBreakpoint;
  final Script script;
  final vm.Stack stack;
  final void Function(Script script, int line) onSelected;

  @override
  _CodeViewState createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> {
  List<String> lines = [];
  Set<int> executableLines = {};
  LinkedScrollControllerGroup verticalController;
  ScrollController gutterController;
  ScrollController textController;

  // The paused positions in the current [widget.script] from the [widget.stack].
  List<int> pausedPositions;

  @override
  void initState() {
    super.initState();

    verticalController = LinkedScrollControllerGroup();
    gutterController = verticalController.addAndGet();
    textController = verticalController.addAndGet();
    _updateLines();
    _updatePausedPositions();
  }

  @override
  void dispose() {
    super.dispose();

    gutterController.dispose();
    textController.dispose();
  }

  @override
  void didUpdateWidget(CodeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.script != oldWidget.script) {
      _updateLines();
    }

    if (widget.stack != oldWidget.stack) {
      _updatePausedPositions();
    }
  }

  void _updateLines() {
    setState(() {
      lines = widget.script?.source?.split('\n') ?? [];

      executableLines = {};

      // Recalculate the executable lines.
      if (widget.script?.tokenPosTable != null) {
        for (var encodedInfo in widget.script.tokenPosTable) {
          executableLines.add(encodedInfo[0]);
        }
      }
    });
  }

  void _updatePausedPositions() {
    setState(() {
      final framesInScript = (widget.stack?.frames ?? [])
          .where((frame) => frame.location.script.id == widget.script?.id);
      pausedPositions = [
        for (var frame in framesInScript)
          widget.controller.lineNumber(widget.script, frame.location)
      ];
    });

    if (pausedPositions.isNotEmpty) {
      final lineIndex = pausedPositions.first - 1;
      // Back up 10 lines so the execution point isn't right at the top.
      final scrollPosition = (lineIndex - 10) * CodeView.rowHeight;
      verticalController.animateTo(
        math.max(0, scrollPosition),
        duration: shortDuration,
        curve: defaultCurve,
      );
    }
  }

  void _onPressed(int line) {
    widget.onSelected(widget.script, line);
  }

  @override
  Widget build(BuildContext context) {
    // TODO(#1648): Implement syntax highlighting.

    if (widget.script == null) {
      return Center(
        child: Text(
          'No script selected',
          style: Theme.of(context).textTheme.subtitle1,
        ),
      );
    }

    // Apply the log change-of-base formula, then add 16dp padding for every
    // digit in the maximum number of lines.
    final gutterWidth = lines.isEmpty
        ? CodeView.assumedCharacterWidth
        : CodeView.assumedCharacterWidth *
                (math.log(lines.length) / math.ln10) +
            CodeView.assumedCharacterWidth;

    return DefaultTextStyle(
      style: Theme.of(context)
          .textTheme
          .bodyText2
          .copyWith(fontFamily: 'RobotoMono'),
      child: Scrollbar(
        child: Row(
          children: [
            SizedBox(
              width: gutterWidth,
              child: ListView.builder(
                controller: gutterController,
                itemExtent: CodeView.rowHeight,
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  final lineNum = index + 1;
                  return GutterRow(
                    lineNumber: lineNum,
                    totalLines: lines.length,
                    onPressed: () => _onPressed(lineNum),
                    isBreakpoint:
                        widget.lineNumberToBreakpoint.containsKey(lineNum),
                    isExecutable: executableLines.contains(lineNum),
                    isPausedHere: pausedPositions.contains(lineNum),
                  );
                },
              ),
            ),
            const SizedBox(width: denseSpacing),
            Expanded(
              child: ListView.builder(
                controller: textController,
                itemExtent: CodeView.rowHeight,
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  final lineNum = index + 1;
                  return ScriptRow(
                    lineContents: lines[index],
                    onPressed: () => _onPressed(lineNum),
                    isPausedHere: pausedPositions.contains(lineNum),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GutterRow extends StatelessWidget {
  const GutterRow({
    Key key,
    @required this.lineNumber,
    @required this.totalLines,
    @required this.isBreakpoint,
    @required this.isExecutable,
    @required this.isPausedHere,
    @required this.onPressed,
  }) : super(key: key);

  final int lineNumber;
  final int totalLines;
  final bool isBreakpoint;
  final bool isExecutable;

  /// Whether the execution point is currently paused here.
  final bool isPausedHere;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final foregroundColor = theme.textTheme.bodyText2.color;
    final subtleColor = theme.unselectedWidgetColor;

    const bpBoxSize = 12.0;
    const executionPointIndent = 8.0;

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
                  child: Stack(
                    alignment: AlignmentDirectional.center,
                    children: [
                      if (isExecutable)
                        createCircleWidget(executableLineRadius, subtleColor),
                      if (isBreakpoint)
                        createCircleWidget(breakpointRadius, foregroundColor),
                    ],
                  ),
                ),
              ),
            Text('$lineNumber', textAlign: TextAlign.end),
            if (isPausedHere)
              const Padding(
                padding: EdgeInsets.only(left: executionPointIndent),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(Icons.play_arrow, size: defaultIconSize),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ScriptRow extends StatelessWidget {
  const ScriptRow({
    Key key,
    @required this.lineContents,
    @required this.onPressed,
    @required this.isPausedHere,
  }) : super(key: key);

  final String lineContents;
  final VoidCallback onPressed;
  final bool isPausedHere;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final regularStyle = TextStyle(color: theme.textTheme.bodyText2.color);
    final selectedStyle = TextStyle(color: theme.textSelectionColor);

    return InkWell(
      onTap: onPressed,
      child: Container(
        alignment: Alignment.centerLeft,
        height: CodeView.rowHeight,
        color: isPausedHere ? theme.selectedRowColor : null,
        child: Text(lineContents,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: isPausedHere ? selectedStyle : regularStyle),
      ),
    );
  }
}
