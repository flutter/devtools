// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../common_widgets.dart';
import '../../globals.dart';
import '../../theme.dart';
import '../console.dart';
import '../console_service.dart';
import 'evaluate.dart';

// TODO(devoncarew): Show some small UI indicator when we receive stdout/stderr.

@override
PreferredSizeWidget buildConsolePaneHeader() {
  return AreaPaneHeader(
    title: const Text('Console'),
    needsTopBorder: false,
    actions: [
      CopyToClipboardControl(
        dataProvider: () =>
            serviceManager.consoleService.stdio.value.join('\n'),
        buttonKey: ConsolePane.copyToClipboardButtonKey,
      ),
      DeleteControl(
        buttonKey: ConsolePane.clearStdioButtonKey,
        tooltip: 'Clear console output',
        onPressed: () => serviceManager.consoleService.clearStdio(),
      ),
    ],
  );
}

/// Display the stdout and stderr output from the process under debug.
class ConsolePane extends StatefulWidget {
  const ConsolePane({
    Key? key,
  }) : super(key: key);

  static const copyToClipboardButtonKey =
      Key('console_copy_to_clipboard_button');
  static const clearStdioButtonKey = Key('console_clear_stdio_button');

  @override
  State<ConsolePane> createState() => _ConsolePaneState();
}

class _ConsolePaneState extends State<ConsolePane> {
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
              child: const ExpressionEvalField(),
            ),
          ),
        ),
      ],
    );
  }
}
