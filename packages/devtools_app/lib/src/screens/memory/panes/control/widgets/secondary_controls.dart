// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/file_import.dart';
import '../../../../../shared/screen.dart';
import '../../../shared/primitives/simple_elements.dart';
import '../controller/control_pane_controller.dart';
import 'settings_dialog.dart';

/// Controls related to the entire memory screen.
class SecondaryControls extends StatelessWidget {
  const SecondaryControls({
    super.key,
    required this.controller,
    required this.offline,
  });

  final MemoryControlPaneController controller;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!offline)
          GaDevToolsButton(
            onPressed: controller.isGcing ? null : controller.gc,
            icon: Icons.delete,
            label: 'GC',
            tooltip: 'Trigger full garbage collection.',
            minScreenWidthForTextBeforeScaling: memoryControlsMinVerboseWidth,
            gaScreen: gac.memory,
            gaSelection: gac.MemoryEvent.gc,
          ),
        const SizedBox(width: denseSpacing),
        OpenSaveButtonGroup(
          screenId: ScreenMetaData.memory.id,
          onSave: controller.exportData,
        ),
        const SizedBox(width: denseSpacing),
        SettingsOutlinedButton(
          gaScreen: gac.memory,
          gaSelection: gac.MemoryEvent.settings,
          onPressed: () => _openSettingsDialog(context),
          tooltip: 'Open memory settings',
        ),
      ],
    );
  }

  void _openSettingsDialog(BuildContext context) {
    unawaited(
      showDialog(
        context: context,
        builder: (context) => const MemorySettingsDialog(),
      ),
    );
  }
}
