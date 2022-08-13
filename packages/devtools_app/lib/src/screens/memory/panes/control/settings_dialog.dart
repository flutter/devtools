// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/common_widgets.dart';
import '../../../../shared/dialogs.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/theme.dart';
import '../../memory_controller.dart';

class MemorySettingsDialog extends StatelessWidget {
  const MemorySettingsDialog(this.controller);

  final MemoryController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DevToolsDialog(
      title: dialogTitleText(theme, 'Memory Settings'),
      includeDivider: false,
      content: Container(
        width: defaultDialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxSetting(
              notifier: preferences.memory.androidCollectionEnabled
                  as ValueNotifier<bool?>,
              title: 'Show Android memory chart',
            ),
            const SizedBox(
              height: defaultSpacing,
            ),
            CheckboxSetting(
              notifier: preferences.memory.autoSnapshotEnabled
                  as ValueNotifier<bool?>,
              title: 'Automatically take snapshot when memory usage spikes',
            ),
          ],
        ),
      ),
      actions: [
        DialogCloseButton(),
      ],
    );
  }
}
