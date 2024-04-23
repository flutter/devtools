// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../common_widgets.dart';
import '../../globals.dart';
import '../console.dart';
import '../console_service.dart';
import 'evaluate.dart';
import 'help_dialog.dart';

// TODO(devoncarew): Show some small UI indicator when we receive stdout/stderr.

class ConsolePaneHeader extends AreaPaneHeader {
  ConsolePaneHeader({super.key})
      : super(
          title: const Text('Console'),
          roundedTopBorder: true,
          actions: [
            const ConsoleHelpLink(),
            const SizedBox(width: densePadding),
            CopyToClipboardControl(
              dataProvider: () =>
                  serviceConnection.consoleService.stdio.value.join('\n'),
              buttonKey: ConsolePane.copyToClipboardButtonKey,
            ),
            const SizedBox(width: densePadding),
            DeleteControl(
              buttonKey: ConsolePane.clearStdioButtonKey,
              tooltip: 'Clear console output',
              onPressed: () => serviceConnection.consoleService.clearStdio(),
            ),
          ],
        );
}

/// Display the stdout and stderr output from the process under debug.
class ConsolePane extends StatelessWidget {
  const ConsolePane({
    super.key,
  });

  static const copyToClipboardButtonKey =
      Key('console_copy_to_clipboard_button');
  static const clearStdioButtonKey = Key('console_clear_stdio_button');

  ValueListenable<List<ConsoleLine>> get stdio =>
      serviceConnection.consoleService.stdio;

  @override
  Widget build(BuildContext context) {
    final Widget? footer;

    // Eval is disabled for profile mode.
    if (serviceConnection.serviceManager.connectedApp!.isProfileBuildNow!) {
      footer = null;
    } else {
      footer = const ExpressionEvalField();
    }

    return Column(
      children: [
        Expanded(
          child: Console(
            lines: stdio,
            footer: footer,
          ),
        ),
      ],
    );
  }
}
