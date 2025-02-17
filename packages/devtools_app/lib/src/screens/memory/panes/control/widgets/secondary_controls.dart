// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/feature_flags.dart';
import '../../../../../shared/framework/screen.dart';
import '../../../../../shared/globals.dart';
import '../../../../../shared/ui/common_widgets.dart';
import '../../../../../shared/ui/file_import.dart';
import '../../../shared/primitives/simple_elements.dart';
import 'settings_dialog.dart';

/// Controls related to the entire memory screen.
class SecondaryControls extends StatelessWidget {
  const SecondaryControls({
    super.key,
    required this.isGcing,
    required this.onGc,
    required this.onSave,
  });

  final VoidCallback onGc;
  final VoidCallback onSave;
  final ValueListenable<bool> isGcing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!offlineDataController.showingOfflineData.value) ...[
          ValueListenableBuilder(
            valueListenable: isGcing,
            builder: (context, gcing, _) {
              return GaDevToolsButton(
                onPressed: gcing ? null : onGc,
                icon: Icons.delete,
                label: 'GC',
                tooltip: 'Trigger full garbage collection.',
                minScreenWidthForTextBeforeScaling:
                    memoryControlsMinVerboseWidth,
                gaScreen: gac.memory,
                gaSelection: gac.MemoryEvents.gc.name,
              );
            },
          ),
          const SizedBox(width: denseSpacing),
        ],
        if (FeatureFlags.memorySaveLoad) ...[
          OpenSaveButtonGroup(
            screenId: ScreenMetaData.memory.id,
            onSave: (_) => onSave(),
          ),
          const SizedBox(width: denseSpacing),
        ],
        SettingsOutlinedButton(
          gaScreen: gac.memory,
          gaSelection: gac.MemoryEvents.settings.name,
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
