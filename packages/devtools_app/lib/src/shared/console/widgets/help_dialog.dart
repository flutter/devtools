// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../shared/analytics/constants.dart' as gac;
import '../../common_widgets.dart';

class ConsoleHelpLink extends StatelessWidget {
  const ConsoleHelpLink({Key? key}) : super(key: key);

  static const _documentationTopic = gac.consoleHelp;

  HelpButtonWithDialog _createButton() => HelpButtonWithDialog(
        asAction: true,
        gaScreen: gac.memory,
        gaSelection: gac.topicDocumentationButton(_documentationTopic),
        dialogTitle: 'Console Help',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(r'''
Use debug console:
1. To watch stdout of the application
2. To evaluate expressions for a paused or running application.
3. To analyze inbound and outbound references for objects, dropped from memory heap snapshots.

Assign previously evaluated objects to variable
using $0, $1 … $5, e.g: var x = $0.
'''),
            MoreInfoLink(
              // TODO(polina-c): create content at link.
              url:
                  'https://docs.flutter.dev/development/tools/devtools/console',
              gaScreenName: '',
              gaSelectedItemDescription:
                  gac.topicDocumentationLink(_documentationTopic),
            ),
          ],
        ),
      );

  void openDialog(BuildContext context) => _createButton().openDialog(context);

  @override
  Widget build(BuildContext context) => _createButton();
}
