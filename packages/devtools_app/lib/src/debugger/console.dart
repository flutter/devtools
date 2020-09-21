// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../common_widgets.dart';
import '../console.dart';
import '../utils.dart';
import 'debugger_controller.dart';
import 'evaluate.dart';

// TODO(devoncarew): Show some small UI indicator when we receive stdout/stderr.

/// Display the stdout and stderr output from the process under debug.
class DebuggerConsole extends StatefulWidget {
  const DebuggerConsole({
    Key key,
    this.controller,
  }) : super(key: key);

  final DebuggerController controller;

  @override
  _DebuggerConsoleState createState() => _DebuggerConsoleState();

  static const copyToClipboardButtonKey =
      Key('debugger_console_copy_to_clipboard_button');
  static const clearStdioButtonKey = Key('debugger_console_clear_stdio_button');
}

class _DebuggerConsoleState extends State<DebuggerConsole> {
  var _lines = <String>[];

  @override
  void initState() {
    super.initState();

    _lines = widget.controller.stdio.value;
    widget.controller.stdio.addListener(_onStdioChanged);
  }

  void _onStdioChanged() {
    setState(() {
      _lines = widget.controller.stdio.value;
    });
  }

  @override
  void dispose() {
    widget.controller.stdio.removeListener(_onStdioChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final numLines = _lines.length;
    final disabled = numLines == 0;

    return OutlineDecoration(
      child: Column(
        children: [
          Expanded(
            child: Console(
              title: areaPaneHeader(
                context,
                title: 'Console',
                needsTopBorder: false,
                actions: [
                  CopyToClipboardControl(
                    dataProvider: disabled ? null : () => _lines.join('\n'),
                    successMessage:
                        'Copied $numLines ${pluralize('line', numLines)}.',
                    buttonKey: DebuggerConsole.copyToClipboardButtonKey,
                  ),
                  DeleteControl(
                    buttonKey: DebuggerConsole.clearStdioButtonKey,
                    tooltip: 'Clear console output',
                    onPressed: disabled ? null : widget.controller.clearStdio,
                  ),
                ],
              ),
              lines: _lines,
            ),
          ),
          ExpressionEvalField(controller: widget.controller),
        ],
      ),
    );
  }
}
