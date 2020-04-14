// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart' hide Stack;
import 'package:vm_service/vm_service.dart';

import '../../flutter/flutter_widgets/linked_scroll_controller.dart';
import '../../flutter/theme.dart';
import 'debugger_controller.dart';

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
  final Stack stack;
  final void Function(Script script, int line) onSelected;

  @override
  _CodeViewState createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> {
  List<String> lines = [];
  ScrollController _horizontalController;
  LinkedScrollControllerGroup verticalController;
  ScrollController gutterController;
  ScrollController textController;

  // The paused positions in the current [widget.script] from the [widget.stack].
  List<int> pausedPositions;

  @override
  void initState() {
    super.initState();

    _horizontalController = ScrollController();
    verticalController = LinkedScrollControllerGroup();
    gutterController = verticalController.addAndGet();
    textController = verticalController.addAndGet();
    _updateLines();
    _updatePausedPositions();
  }

  @override
  void dispose() {
    super.dispose();

    _horizontalController.dispose();
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
    // TODO(https://github.com/flutter/devtools/issues/1648): Line numbers,
    // syntax highlighting and breakpoint markers.
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
                    isPausedHere: pausedPositions.contains(lineNum),
                  );
                },
              ),
            ),
            const SizedBox(width: denseSpacing),
            Expanded(
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: CodeView.assumedCharacterWidth *
                      lines
                          .map((s) => s.length)
                          .reduce((a, b) => math.max(a, b)),
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
    @required this.onPressed,
    @required this.isBreakpoint,
    this.isPausedHere = false,
  }) : super(key: key);

  final int lineNumber;
  final int totalLines;
  final VoidCallback onPressed;

  // TODO(djshuckerow): Add support for multiple breakpoints in a line.
  final bool isBreakpoint;

  /// Whether the execution point is currently paused here.
  final bool isPausedHere;

  @override
  Widget build(BuildContext context) {
    // TODO(devoncarew): Improve the layout of the breakpoint and execution
    // marker.

    return InkWell(
      onTap: onPressed,
      child: Container(
        height: CodeView.rowHeight,
        padding: const EdgeInsets.only(left: 2.0, right: 4.0),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(color: titleSolidBackgroundColor),
        child: Row(
          children: [
            if (isPausedHere)
              const Icon(Icons.play_arrow, size: defaultIconSize),
            if (isBreakpoint && !isPausedHere)
              const Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Text('●'),
              ),
            Expanded(
              child: Text(
                '$lineNumber',
                textAlign: TextAlign.end,
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
    return InkWell(
      onTap: onPressed,
      child: Container(
        alignment: Alignment.centerLeft,
        height: CodeView.rowHeight,
        color: isPausedHere ? Theme.of(context).selectedRowColor : null,
        child: Text(
          lineContents,
          style: isPausedHere
              ? TextStyle(color: Theme.of(context).textSelectionColor)
              : null,
        ),
      ),
    );
  }
}
