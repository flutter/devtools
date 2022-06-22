// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../analytics/analytics.dart' as ga;
import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/listenable.dart';
import '../../shared/banner_messages.dart';
import '../../shared/screen.dart';
import '../../shared/utils.dart';
import '../../ui/icons.dart';
import 'memory_controller.dart';
import 'memory_heap_tree_view.dart';
import 'panes/chart/chart_pane.dart';
import 'panes/chart/memory_android_chart.dart' as android;
import 'panes/chart/memory_events_pane.dart' as events;
import 'panes/chart/memory_vm_chart.dart' as vm;
import 'panes/control/control_pane.dart';

class MemoryScreen extends Screen {
  const MemoryScreen()
      : super.conditional(
          id: id,
          requiresDartVm: true,
          title: 'Memory',
          icon: Octicons.package,
        );

  static const id = 'memory';

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

  late ChartControllers _chartControllers;

  final _keyPressed = ValueNotifier<RawKeyEvent?>(null);

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

    final vmChartController = vm.VMChartController(controller);
    _chartControllers = ChartControllers(
      event: events.EventChartController(controller),
      vm: vmChartController,
      android: android.AndroidChartController(
        controller,
        sharedLabels: vmChartController.labelTimestamps,
      ),
    );

    // Update the chart when the memorySource changes.
    addAutoDisposeListener(memoryController.selectedSnapshotNotifier, () {
      setState(() {
        // TODO(terry): Create the snapshot data to display by Library,
        //              by Class or by Objects.
        // Create the snapshot data by Library.
        memoryController.createSnapshotByLibrary();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // TODO(terry): Can Flutter's focus system be used instead of listening to keyboard?
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: (RawKeyEvent event) => _keyPressed.value = event,
      autofocus: true,
      child: Column(
        key: MemoryChartPane.hoverKey,
        children: [
          MemoryControlPane(chartControllers: _chartControllers),
          MemoryChartPane(
            chartControllers: _chartControllers,
            keyPressed: _keyPressed,
          ),
          Expanded(
            child: HeapTree(memoryController),
          ),
        ],
      ),
    );
  }
}
