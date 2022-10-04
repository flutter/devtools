// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/common_widgets.dart';
import '../../shared/console.dart';
import '../../shared/console_service.dart';
import '../../shared/globals.dart';
import '../../shared/theme.dart';
import 'debugger_controller.dart';
import 'evaluate.dart';

// TODO(devoncarew): Show some small UI indicator when we receive stdout/stderr.

/// Display the stdout and stderr output from the process under debug.
class DebuggerConsole extends StatefulWidget {
  const DebuggerConsole({
    Key? key,
  }) : super(key: key);

  static const copyToClipboardButtonKey =
      Key('debugger_console_copy_to_clipboard_button');
  static const clearStdioButtonKey = Key('debugger_console_clear_stdio_button');

  @override
  State<DebuggerConsole> createState() => _DebuggerConsoleState();

  static PreferredSizeWidget buildHeader() {
    return AreaPaneHeader(
      title: const Text('Console'),
      needsTopBorder: false,
      actions: [
        CopyToClipboardControl(
          dataProvider: () =>
              serviceManager.consoleService.stdio.value.join('\n'),
          buttonKey: DebuggerConsole.copyToClipboardButtonKey,
        ),
        DeleteControl(
          buttonKey: DebuggerConsole.clearStdioButtonKey,
          tooltip: 'Clear console output',
          onPressed: () => serviceManager.consoleService.clearStdio(),
        ),
      ],
    );
  }
}

class _DebuggerConsoleState extends State<DebuggerConsole> {
  ValueListenable<List<ConsoleLine>> get stdio =>
      serviceManager.consoleService.stdio;

  @override
  void initState() {
    super.initState();
    serviceManager.consoleService.ensureServiceInitialized();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Console(
            lines: stdio,
            footer: SizedBox(
              height: consoleLineHeight,
              child: ExpressionEvalField(
                controller:
                    Provider.of<DebuggerController>(context, listen: false),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
