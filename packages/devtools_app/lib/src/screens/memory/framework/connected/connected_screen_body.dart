// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/banner_messages.dart';
import '../../../../shared/primitives/auto_dispose.dart';
import '../../../../shared/primitives/simple_items.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/utils.dart';
import '../../panes/chart/chart_pane.dart';
import '../../panes/chart/chart_pane_controller.dart';
import '../../panes/chart/memory_android_chart.dart';
import '../../panes/chart/memory_events_pane.dart';
import '../../panes/chart/memory_vm_chart.dart';
import '../../panes/control/control_pane.dart';
import 'memory_controller.dart';
import 'memory_tabs.dart';

class ConnectedMemoryBody extends StatefulWidget {
  const ConnectedMemoryBody({super.key});

  @override
  State<ConnectedMemoryBody> createState() => _ConnectedMemoryBodyState();
}

class _ConnectedMemoryBodyState extends State<ConnectedMemoryBody>
    with
        AutoDisposeMixin,
        SingleTickerProviderStateMixin,
        ProvidedControllerMixin<MemoryController, ConnectedMemoryBody> {
  MemoryController get memoryController => controller;

  late MemoryChartPaneController _chartController;

  final _focusNode = FocusNode(debugLabel: 'memory');

  @override
  void initState() {
    super.initState();
    autoDisposeFocusNode(_focusNode);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maybePushDebugModeMemoryMessage(context, ScreenMetaData.memory.id);
    if (!initController()) return;

    final vmChartController = VMChartController(controller);
    _chartController = MemoryChartPaneController(
      event: EventChartController(controller),
      vm: vmChartController,
      android: AndroidChartController(
        controller,
        sharedLabels: vmChartController.labelTimestamps,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: MemoryChartPane.hoverKey,
      children: [
        MemoryControlPane(controller: controller),
        const SizedBox(height: intermediateSpacing),
        MemoryChartPane(
          chartController: _chartController,
          keyFocusNode: _focusNode,
        ),
        Expanded(
          child: MemoryTabView(memoryController),
        ),
      ],
    );
  }
}
