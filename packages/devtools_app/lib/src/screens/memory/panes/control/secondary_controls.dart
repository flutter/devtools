// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../analytics/analytics.dart' as ga;
import '../../../../analytics/constants.dart' as analytics_constants;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/theme.dart';
import '../../memory_controller.dart';
import '../../primitives/ui.dart';
import '../../shared/constants.dart';
import '../chart/chart_pane_controller.dart';
import 'settings_dialog.dart';
import 'source_dropdown.dart';

/// Controls related to the entire memory screen.
class SecondaryControls extends StatefulWidget {
  const SecondaryControls({
    Key? key,
    required this.chartController,
    required this.controller,
  }) : super(key: key);

  final MemoryChartPaneController chartController;
  final MemoryController controller;

  @override
  State<SecondaryControls> createState() => _SecondaryControlsState();
}

class _SecondaryControlsState extends State<SecondaryControls> {
  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.of(context).size.width;
    widget.controller.memorySourcePrefix =
        mediaWidth > verboseDropDownMinimumWidth
            ? memorySourceMenuItemPrefix
            : '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MemorySourceDropdown(),
        const SizedBox(width: denseSpacing),
        IconLabelButton(
          onPressed: widget.controller.isGcing ? null : _gc,
          icon: Icons.delete,
          label: 'GC',
          tooltip: 'Trigger full garbage collection.',
          minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
        ),
        const SizedBox(width: denseSpacing),
        ExportButton(
          onPressed: widget.controller.offline.value ? null : _exportToFile,
          minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
        ),
        const SizedBox(width: denseSpacing),
        SettingsOutlinedButton(
          onPressed: _openSettingsDialog,
          tooltip: 'Open memory settings',
        ),
      ],
    );
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => MemorySettingsDialog(widget.controller),
    );
  }

  void _exportToFile() {
    final outputPath = widget.controller.memoryLog.exportMemory();
    notificationService.push(
      'Successfully exported file ${outputPath.last} to ${outputPath.first} directory',
    );
  }

  Future<void> _gc() async {
    ga.select(analytics_constants.memory, analytics_constants.gc);
    widget.controller.memoryTimeline.addGCEvent();
    await widget.controller.gc();
  }
}
