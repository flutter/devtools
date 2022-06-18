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
            ...dialogSubHeader(theme, 'Android'),
            Column(
              children: [
                // TODO(polinach): use CheckboxSetting instead
                Row(
                  children: [
                    NotifierCheckbox(
                      notifier: preferences.memory.androidCollectionEnabled
                          as ValueNotifier<bool?>,
                    ),
                    RichText(
                      overflow: TextOverflow.visible,
                      text: TextSpan(
                        text: 'Show Android memory chart',
                        style: theme.regularTextStyle,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    NotifierCheckbox(
                      notifier:
                          controller.unitDisplayed as ValueNotifier<bool?>,
                    ),
                    RichText(
                      overflow: TextOverflow.visible,
                      text: TextSpan(
                        text: 'Display Data In Units (B, KB, MB, and GB)',
                        style: theme.regularTextStyle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(
              height: defaultSpacing,
            ),
            ...dialogSubHeader(theme, 'General'),
            Row(
              children: [
                NotifierCheckbox(
                  notifier: controller.advancedSettingsEnabled
                      as ValueNotifier<bool?>,
                ),
                RichText(
                  overflow: TextOverflow.visible,
                  text: TextSpan(
                    text: 'Enable advanced memory settings',
                    style: theme.regularTextStyle,
                  ),
                ),
              ],
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
