// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/globals.dart';

/// The dialog keys for testing purposes.
@visibleForTesting
class MemorySettingDialogKeys {
  static const Key showAndroidChartCheckBox = ValueKey('showAndroidChart');
}

class MemorySettingsDialog extends StatelessWidget {
  const MemorySettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DevToolsDialog(
      title: const DialogTitleText('Memory Settings'),
      includeDivider: false,
      content: SizedBox(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(preferences.memory.refLimitTitle),
                      Text(
                        'Used to explore live references in console.',
                        style: theme.subtleTextStyle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: defaultSpacing),
                SizedBox(
                  height: defaultTextFieldHeight,
                  width: defaultTextFieldNumberWidth,
                  child: TextField(
                    style: theme.regularTextStyle,
                    decoration: singleLineDialogTextFieldDecoration,
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
