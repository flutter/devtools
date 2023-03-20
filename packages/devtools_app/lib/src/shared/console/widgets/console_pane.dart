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

class ConsolePaneHeader extends AreaPaneHeader {
  ConsolePaneHeader({Color? backgroundColor})
      : super(
          key: theKey,
          title: const Text('Console'),
          roundedTopBorder: true,
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

  static const theKey = Key('ConsolePaneHeader');
}

/// Defines relative height of console in DevTools.
///
/// To set the in debug configuration of VSCode, add value:
///   "args": [
///     "--dart-define=console_height_percent=90"
///   ]
const int consoleHeightPercent =
    int.fromEnvironment('console_height_percent', defaultValue: 20);

/// Display the stdout and stderr output from the process under debug.
class ConsolePane extends StatelessWidget {
  const ConsolePane({
    Key? key,
  }) : super(key: key);

  static const copyToClipboardButtonKey =
      Key('console_copy_to_clipboard_button');
  static const clearStdioButtonKey = Key('console_clear_stdio_button');

  ValueListenable<List<ConsoleLine>> get stdio =>
      serviceManager.consoleService.stdio;

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
