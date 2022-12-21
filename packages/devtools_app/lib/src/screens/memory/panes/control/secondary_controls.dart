// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/analytics/analytics.dart' as ga;
import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/theme.dart';
import '../../memory_controller.dart';
import '../../shared/primitives/simple_elements.dart';
import '../chart/chart_pane_controller.dart';
import 'primitives.dart';
import 'settings_dialog.dart';
import 'source_dropdown.dart';

/// Controls related to the entire memory screen.
class SecondaryControls extends StatelessWidget {
  const SecondaryControls({
    Key? key,
    required this.chartController,
    required this.controller,
  }) : super(key: key);

  final MemoryChartPaneController chartController;
  final MemoryController controller;

  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.of(context).size.width;
    controller.memorySourcePrefix = mediaWidth > memoryControlsMinVerboseWidth
        ? memorySourceMenuItemPrefix
        : '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MemorySourceDropdown(),
        const SizedBox(width: denseSpacing),
        IconLabelButton(
          onPressed: controller.isGcing ? null : _gc,
          icon: Icons.delete,
          label: 'GC',
          tooltip: 'Trigger full garbage collection.',
          minScreenWidthForTextBeforeScaling: memoryControlsMinVerboseWidth,
        ),
        const SizedBox(width: denseSpacing),
        ExportButton(
          onPressed: controller.offline.value ? null : _exportToFile,
          minScreenWidthForTextBeforeScaling: memoryControlsMinVerboseWidth,
        ),
        const SizedBox(width: denseSpacing),
        SettingsOutlinedButton(
          onPressed: () => _openSettingsDialog(context),
          tooltip: 'Open memory settings',
        ),
      ],
    );
  }

  void _openSettingsDialog(BuildContext context) {
    ga.select(
      gac.memory,
      gac.MemoryEvent.settings,
    );
    unawaited(
      showDialog(
        context: context,
        builder: (context) => MemorySettingsDialog(controller),
      ),
    );
  }

  void _exportToFile() {
    final outputPath = controller.memoryLog.exportMemory();
    notificationService.push(
      'Successfully exported file ${outputPath.last} to ${outputPath.first} directory',
    );
  }

  Future<void> _gc() async {
    ga.select(
      gac.memory,
      gac.MemoryEvent.gc,
    );
    controller.memoryTimeline.addGCEvent();
    await controller.gc();
  }
}
