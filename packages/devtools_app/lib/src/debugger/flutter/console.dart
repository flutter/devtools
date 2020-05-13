// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../flutter/common_widgets.dart';
import '../../flutter/theme.dart';
import '../../flutter/utils.dart';
import 'codeview.dart';
import 'debugger_controller.dart';

// TODO(devoncarew): Allow scrolling horizontally as well.

// TODO(devoncarew): Show some small UI indicator when we receive stdout/stderr.

// TODO(devoncarew): Support hyperlinking to stack traces.

/// Display the stdout and stderr output from the process under debug.
class DebuggerConsole extends StatefulWidget {
  const DebuggerConsole({
    Key key,
    this.controller,
  }) : super(key: key);

  final DebuggerController controller;

  @override
  _DebuggerConsoleState createState() => _DebuggerConsoleState();

  static const copyToClipboardButtonKey = Key('debugger_console_copy_to_clipboard_button');
  static const clearStdioButtonKey = Key('debugger_console_clear_stdio_button');
}

class _DebuggerConsoleState extends State<DebuggerConsole> {
  var _lines = <String>[];

  void _onStdioChanged() {
    setState(() {
      _lines = widget.controller.stdio.value;
    });
  }

  @override
  void initState() {
    _lines = widget.controller.stdio.value;
    widget.controller.stdio.addListener(_onStdioChanged);
    super.initState();
  }

  @override
  void dispose() {
    widget.controller.stdio.removeListener(_onStdioChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Console(
      lines: _lines,
      controls: [
        if (_lines.isNotEmpty) ...[
          IconButton(
            icon: const Icon(Icons.content_copy),
            onPressed: () => copyToClipboard(_lines, context),
            tooltip: 'Copy to clipboard',
            key: DebuggerConsole.copyToClipboardButtonKey,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: widget.controller.clearStdio,
            tooltip: 'Clear console output',
            key: DebuggerConsole.clearStdioButtonKey,
          ),
        ],
      ],
    );
  }
}

/// Renders a ConsoleOutput widget with ConsoleControls overlaid on the top-right corner.
///
/// TODO(ditman): Reuse this in `logging/flutter/logging_screen.dart`?
class Console extends StatelessWidget {
  const Console({
    this.controls = const <Widget>[],
    this.lines = const <String>[],
  }) : super();

  final List<Widget> controls;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _ConsoleOutput(lines: lines),
        if (controls.isNotEmpty) ...[
          _ConsoleControls(
            controls: controls,
          ),
        ],
      ],
    );
  }
}

/// Renders a top-right aligned ButtonBar wrapping a List of IconButtons (`controls`).
class _ConsoleControls extends StatelessWidget {
  const _ConsoleControls({
    this.controls,
  }) : super();

  final List<Widget> controls;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.topRight,
      child: ButtonBar(
        buttonPadding: EdgeInsets.zero,
        alignment: MainAxisAlignment.end,
        children: controls,
      ),
    );
  }
}

/// Renders a widget with the output of the console.
///
/// This is a ListView of text lines, with a monospace font and a border.
class _ConsoleOutput extends StatefulWidget {
  const _ConsoleOutput({
    Key key,
    this.lines,
  }) : super(key: key);

  final List<String> lines;

  @override
  _ConsoleOutputState createState() => _ConsoleOutputState();
}

class _ConsoleOutputState extends State<_ConsoleOutput> {
  // The scroll controller must survive ConsoleOutput re-renders
  // to work as intended, so it must be part of the "state".
  final ScrollController _scroll = ScrollController();

  // Whenever the widget updates, refresh the scroll position if needed.
  @override
  void didUpdateWidget(oldWidget) {
    if (_scroll.hasClients && _scroll.atScrollBottom) {
      _scroll.autoScrollToBottom();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle =
        theme.textTheme.bodyText2.copyWith(fontFamily: 'RobotoMono');

    return OutlineDecoration(
      child: Scrollbar(
        child: ListView.builder(
          padding: const EdgeInsets.all(denseSpacing),
          itemCount: widget.lines.length,
          itemExtent: CodeView.rowHeight,
          controller: _scroll,
          itemBuilder: (context, index) {
            return RichText(
              text: TextSpan(
                children: processAnsiTerminalCodes(
                  widget.lines[index],
                  textStyle,
                ),
              ),
              maxLines: 1,
            );
          },
        ),
      ),
    );
  }
}
