// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/banner_messages.dart';
import '../../shared/primitives/auto_dispose.dart';
import '../../shared/primitives/listenable.dart';
import '../../shared/primitives/simple_items.dart';
import '../../shared/screen.dart';
import '../../shared/theme.dart';
import '../../shared/ui/icons.dart';
import '../../shared/utils.dart';
import 'memory_controller.dart';
import 'memory_tabs.dart';
import 'panes/chart/chart_pane.dart';
import 'panes/chart/chart_pane_controller.dart';
import 'panes/chart/memory_android_chart.dart';
import 'panes/chart/memory_events_pane.dart';
import 'panes/chart/memory_vm_chart.dart';
import 'panes/control/control_pane.dart';

class MemoryScreen extends Screen {
  MemoryScreen()
      : super.conditional(
          id: id,
          requiresDartVm: true,
          title: ScreenMetaData.memory.title,
          icon: Octicons.package,
        );

  static final id = ScreenMetaData.memory.id;

  @override
  ValueListenable<bool> get showIsolateSelector =>
      const FixedValueListenable<bool>(true);

  @override
  String get docPageId => id;

  @override
  Widget build(BuildContext context) => const MemoryBody();
}

class MemoryBody extends StatefulWidget {
  const MemoryBody();

  @override
  MemoryBodyState createState() => MemoryBodyState();
}

class MemoryBodyState extends State<MemoryBody>
    with
        AutoDisposeMixin,
        SingleTickerProviderStateMixin,
        ProvidedControllerMixin<MemoryController, MemoryBody> {
  MemoryController get memoryController => controller;

  late MemoryChartPaneController _chartController;

  final _focusNode = FocusNode(debugLabel: 'memory');

  @override
  void initState() {
    super.initState();
    ga.screen(MemoryScreen.id);
    autoDisposeFocusNode(_focusNode);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maybePushDebugModeMemoryMessage(context, MemoryScreen.id);
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
        MemoryControlPane(
          chartController: _chartController,
          controller: controller,
        ),
        const SizedBox(height: denseRowSpacing),
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
