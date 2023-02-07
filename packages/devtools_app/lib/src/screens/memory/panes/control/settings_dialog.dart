// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/common_widgets.dart';
import '../../../../shared/dialogs.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/theme.dart';
import '../../memory_controller.dart';

/// The dialog keys for testing purposes.
@visibleForTesting
class MemorySettingDialogKeys {
  static const Key showAndroidChartCheckBox = ValueKey('showAndroidChart');
}

class MemorySettingsDialog extends StatelessWidget {
  const MemorySettingsDialog(this.controller);

  final MemoryController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DevToolsDialog(
      title: const DialogTitleText('Memory Settings'),
      includeDivider: false,
      content: Container(
        width: defaultDialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxSetting(
              notifier: preferences.memory.androidCollectionEnabled,
              title:
                  'Show Android memory chart in addition to Dart memory chart',
              checkboxKey: MemorySettingDialogKeys.showAndroidChartCheckBox,
            ),
            const SizedBox(height: defaultSpacing),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Limit for number of listed items in console.',
                      style: theme.regularTextStyle,
                    ),
                    Text(
                      'Number of listed items may be less in case of filtering. For example,\n'
                      'when the screen first requests live items from application and\n'
                      'then shows only items presented in heap snapshot.',
                      style: theme.subtleTextStyle,
                    ),
                  ],
                ),
                const SizedBox(width: defaultSpacing),
                SizedBox(
                  width: defaultTextFieldNumberWidth,
                  child: TextField(
                    decoration: dialogTextFieldDecoration,
                    controller: TextEditingController(
                      text: preferences.memory.refLimit.value.toString(),
                    ),
                    inputFormatters: <TextInputFormatter>[
                      // Only positive integers.
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^[1-9][0-9]*'),
                      ),
                    ],
                    onChanged: (String text) {
                      final newValue = int.parse(text);
                      preferences.memory.refLimit.value = newValue;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: const [
        DialogCloseButton(),
      ],
    );
  }
}
