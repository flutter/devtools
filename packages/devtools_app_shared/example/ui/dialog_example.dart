// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart' as devtools_shared_ui;
import 'package:flutter/material.dart';

/// Example of using a [DevToolsDialog] widget from
/// 'package:devtools_app_shared/ui.dart'.
class MyDialog extends StatelessWidget {
  const MyDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return devtools_shared_ui.DevToolsDialog(
      title: const devtools_shared_ui.DialogTitleText('My Cool Dialog'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Here is the body of my dialog.'),
          SizedBox(height: devtools_shared_ui.denseSpacing),
          Text('It communicates something important'),
        ],
      ),
      actions: [
        devtools_shared_ui.DialogTextButton(
          onPressed: () {
            // Do someting and then remove the dialog.
            Navigator.of(context).pop(devtools_shared_ui.dialogDefaultContext);
          },
          child: const Text('DO SOMETHING'),
        ),
        const devtools_shared_ui.DialogCancelButton(),
      ],
    );
  }
}
