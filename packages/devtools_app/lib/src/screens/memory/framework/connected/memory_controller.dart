// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../../shared/memory/class_name.dart';
import '../../../../shared/memory/heap_graph_loader.dart';
import '../../panes/chart/controller/android_chart_controller.dart';
import '../../panes/chart/controller/chart_pane_controller.dart';
import '../../panes/chart/controller/vm_chart_controller.dart';
import '../../panes/control/controller/control_pane_controller.dart';
import '../../panes/diff/controller/diff_pane_controller.dart';
import '../../panes/profile/profile_pane_controller.dart';
import '../../panes/tracing/tracing_pane_controller.dart';

class MemoryFeatureControllers {
  /// Controllers are passed for testability.
  MemoryFeatureControllers(
    DiffPaneController? diffPaneController,
    ProfilePaneController? profilePaneController, {
    required MemoryController? memoryController,
  }) {
    diff = diffPaneController ?? _createDiffController();
    profile = profilePaneController ?? ProfilePaneController();

    final vmChartController = VMChartController(memoryController!);
    chart = MemoryChartPaneController(
      vm: vmChartController,
      android: AndroidChartController(
        memoryController,
        sharedLabels: vmChartController.labelTimestamps,
      ),
    );
  }

  late DiffPaneController diff;
  late ProfilePaneController profile;
  late MemoryChartPaneController chart;
  TracingPaneController tracing = TracingPaneController();
  MemoryControlPaneController control = MemoryControlPaneController();

  DiffPaneController _createDiffController() =>
      DiffPaneController(HeapGraphLoaderRuntime(chart.memoryTimeline));

  void reset() {
    diff.dispose();
    diff = _createDiffController();

    profile.dispose();
    profile = ProfilePaneController();

    tracing.dispose();
    tracing = TracingPaneController();

    chart.memoryTimeline.reset();
  }

  void dispose() {
    tracing.dispose();
    diff.dispose();
    profile.dispose();
  }
}

/// This class contains the business logic for memory screen, for a connected
/// application.
///
/// This class must not have direct dependencies on web-only libraries. This
/// allows tests of the complicated logic in this class to run on the VM.
///
/// The controller should be recreated for every new connection.
class MemoryController extends DisposableController
    with AutoDisposeControllerMixin {
  MemoryController({
    @visibleForTesting DiffPaneController? diffPaneController,
    @visibleForTesting ProfilePaneController? profilePaneController,
  }) {
    controllers = MemoryFeatureControllers(
      diffPaneController,
      profilePaneController,
      memoryController: this,
    );
    shareClassFilterBetweenProfileAndDiff();
  }

  /// Sub-controllers of memory controller.
  late final MemoryFeatureControllers controllers;

  void shareClassFilterBetweenProfileAndDiff() {
    controllers.diff.derived.applyFilter(
      controllers.profile.classFilter.value,
    );

    controllers.profile.classFilter.addListener(() {
      controllers.diff.derived
          .applyFilter(controllers.profile.classFilter.value);
    });

    controllers.diff.core.classFilter.addListener(() {
      controllers.profile.setFilter(
        controllers.diff.core.classFilter.value,
      );
    });
  }

  /// Index of the selected feature tab.
  ///
  /// This value is used to set the initial tab selection of the
  /// [MemoryTabView]. This widget will be disposed and re-initialized on
  /// DevTools screen changes, so we must store this value in the controller
  /// instead of the widget state.
  int selectedFeatureTabIndex = 0;

  @override
  void dispose() {
    super.dispose();
    unawaited(controllers.chart.memoryTrackerController.close());
    controllers.chart.memoryTracker?.dispose();
    controllers.dispose();
    HeapClassName.dispose();
  }
}
