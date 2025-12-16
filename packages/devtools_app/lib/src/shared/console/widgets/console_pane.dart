// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../framework/scaffold/bottom_pane.dart';
import '../../globals.dart';
import '../../ui/common_widgets.dart';
import '../../ui/tab.dart';
import '../console.dart';
import '../console_service.dart';
import 'evaluate.dart';
import 'help_dialog.dart';

// TODO(devoncarew): Show some small UI indicator when we receive stdout/stderr.

/// Display the stdout and stderr output from the process under debug.
class ConsolePane extends StatelessWidget implements TabbedPane {
  const ConsolePane({super.key});

  static const copyToClipboardButtonKey = Key(
    'console_copy_to_clipboard_button',
  );
  static const clearStdioButtonKey = Key('console_clear_stdio_button');

  static const _tabName = 'Console';

  static const _gaPrefix = 'consolePane';

  @override
  DevToolsTab get tab => DevToolsTab.create(
    tabName: _tabName,
    gaPrefix: _gaPrefix,
    trailing: const _ConsoleActions(),
  );

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

    return Console(lines: stdio, footer: footer);
  }
}

class _ConsoleActions extends StatelessWidget {
  const _ConsoleActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
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
}
