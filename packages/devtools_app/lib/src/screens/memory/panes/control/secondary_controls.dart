// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/analytics/analytics.dart' as ga;
import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/theme.dart';
import '../../memory_controller.dart';
import '../../shared/primitives/simple_elements.dart';
import '../chart/chart_pane_controller.dart';
import 'settings_dialog.dart';

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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconLabelButton(
          onPressed: controller.isGcing ? null : _gc,
          icon: Icons.delete,
          label: 'GC',
          tooltip: 'Trigger full garbage collection.',
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

  Future<void> _gc() async {
    ga.select(
      gac.memory,
      gac.MemoryEvent.gc,
    );
    controller.memoryTimeline.addGCEvent();
    await controller.gc();
  }
}
