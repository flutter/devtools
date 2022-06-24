// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/common_widgets.dart';
import '../../../../shared/dialogs.dart';
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
            ...dialogSubHeader(theme, 'Android'),
            Column(
              children: [
                CheckboxSetting(
                  notifier: controller.androidCollectionEnabled
                      as ValueNotifier<bool?>,
                  title: 'Collect Android Memory Statistics using ADB',
                ),
                CheckboxSetting(
                  notifier: controller.unitDisplayed as ValueNotifier<bool?>,
                  title: 'Display Data In Units (B, KB, MB, and GB)',
                ),
              ],
            ),
            const SizedBox(
              height: defaultSpacing,
            ),
            ...dialogSubHeader(theme, 'General'),
            CheckboxSetting(
              notifier:
                  controller.advancedSettingsEnabled as ValueNotifier<bool?>,
              title: 'Enable advanced memory settings',
            ),
            CheckboxSetting(
              notifier: controller.autoSnapshotEnabled as ValueNotifier<bool?>,
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
