// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/analytics/constants.dart' as gac;
import '../../common_widgets.dart';
import '../../dialogs.dart';

class ConsoleHelpDialog extends StatelessWidget {
  const ConsoleHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    const documentationTopic = gac.consoleHelp;

    return DevToolsDialog(
      title: const DialogTitleText('Console Help'),
      includeDivider: false,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            r'''
Use debug console to:

1. Watch the standard output (stdout) of the application.
2. Evaluate expressions for a paused or running application.
3. Analyze inbound and outbound references for objects, dropped from memory heap snapshots.

Assign previously evaluated objects to variable
using $0, $1 … $5.
Example: var x = $0
''',
          ),
          MoreInfoLink(
            // TODO(polina-c): create content at link.
            url: 'https://docs.flutter.dev/development/tools/devtools/console',
            gaScreenName: gac.memory,
            gaSelectedItemDescription:
                gac.topicDocumentationLink(documentationTopic),
          ),
        ],
      ),
      actions: const [
        DialogCloseButton(),
      ],
    );
  }
}

class ConsoleHelpLink extends StatelessWidget {
  const ConsoleHelpLink({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ToolbarAction(
      icon: Icons.help_outline,
      tooltip: 'Help',
      onPressed: () {
        unawaited(
          showDialog(
            context: context,
            builder: (context) => const ConsoleHelpDialog(),
          ),
        );
      },
    );
  }
}
