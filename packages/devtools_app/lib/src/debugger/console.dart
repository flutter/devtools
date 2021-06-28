// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common_widgets.dart';
import '../console.dart';
import '../console_service.dart';
import '../globals.dart';
import 'debugger_controller.dart';
import 'evaluate.dart';

// TODO(devoncarew): Show some small UI indicator when we receive stdout/stderr.

/// Display the stdout and stderr output from the process under debug.
class DebuggerConsole extends StatelessWidget {
  const DebuggerConsole({
    Key key,
  }) : super(key: key);

  static const copyToClipboardButtonKey =
      Key('debugger_console_copy_to_clipboard_button');
  static const clearStdioButtonKey = Key('debugger_console_clear_stdio_button');

  ValueListenable<List<ConsoleLine>> get stdio =>
      serviceManager.consoleService.stdio;

  @override
  Widget build(BuildContext context) {
    return OutlineDecoration(
      child: Column(
        children: [
          Expanded(
            child: Console(
              title: AreaPaneHeader(
                title: const Text('Console'),
                needsTopBorder: false,
                actions: [
                  CopyToClipboardControl(
                    dataProvider: () => stdio.value?.join('\n') ?? '',
                    buttonKey: DebuggerConsole.copyToClipboardButtonKey,
                  ),
                  DeleteControl(
                    buttonKey: DebuggerConsole.clearStdioButtonKey,
                    tooltip: 'Clear console output',
                    onPressed: () => serviceManager.consoleService.clearStdio(),
                  ),
                ],
              ),
              lines: stdio,
            ),
          ),
          ExpressionEvalField(
            controller: Provider.of<DebuggerController>(context, listen: false),
          ),
        ],
      ),
    );
  }
}
