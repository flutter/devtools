// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../../../devtools_app.dart';
import '../../../../shared/memory/class_name.dart';
import '../../../../shared/memory/heap_graph_loader.dart';
import '../../../../shared/offline_data.dart';
import '../../panes/chart/controller/chart_pane_controller.dart';
import '../../panes/control/controller/control_pane_controller.dart';
import '../../panes/diff/controller/diff_pane_controller.dart';
import '../../panes/profile/profile_pane_controller.dart';
import '../../panes/tracing/tracing_pane_controller.dart';
import '../offline_data/offline_data.dart';

/// This class contains the business logic for memory screen, for a connected
/// application.
///
/// This class must not have direct dependencies on web-only libraries. This
/// allows tests of the complicated logic in this class to run on the VM.
///
/// The controller should be recreated for every new connection.
class MemoryController extends DisposableController
    with
        AutoDisposeControllerMixin,
        OfflineScreenControllerMixin<OfflineMemoryData> {
  MemoryController({
    @visibleForTesting DiffPaneController? diffPaneController,
    @visibleForTesting ProfilePaneController? profilePaneController,
  }) {
    diff = diffPaneController ?? _createDiffController();
    profile = profilePaneController ?? ProfilePaneController();

    shareClassFilterBetweenProfileAndDiff();
  }

  /// Index of the selected feature tab.
  ///
  /// This value is used to set the initial tab selection of the
  /// [MemoryTabView]. This widget will be disposed and re-initialized on
  /// DevTools screen changes, so we must store this value in the controller
  /// instead of the widget state.
  int selectedFeatureTabIndex = 0;

  late DiffPaneController diff;
  late ProfilePaneController profile;
  late MemoryChartPaneController chart = MemoryChartPaneController();
  TracingPaneController tracing = TracingPaneController();
  late final MemoryControlPaneController control =
      MemoryControlPaneController(chart.memoryTimeline, exportData: exportData);

  @override
  void dispose() {
    super.dispose();
    HeapClassName.dispose();
    chart.dispose();
    tracing.dispose();
    diff.dispose();
    profile.dispose();
  }

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

  void shareClassFilterBetweenProfileAndDiff() {
    diff.derived.applyFilter(
      profile.classFilter.value,
    );

    profile.classFilter.addListener(() {
      diff.derived.applyFilter(profile.classFilter.value);
    });

    diff.core.classFilter.addListener(() {
      profile.setFilter(
        diff.core.classFilter.value,
      );
    });
  }

  @override
  OfflineScreenData prepareOfflineScreenData() => OfflineScreenData(
        screenId: ScreenMetaData.memory.id,
        data: OfflineMemoryData().toJson(),
        // {
        //   // 'selectedTab: selectedFeatureTabIndex,
        //   // 'diffData': controllers.diff.prepareForOffline(),
        //   // 'profileData': controllers.profile.prepareForOffline(),
        //   // 'chartData': controllers.chart.prepareForOffline(),
        //   // 'controlData': controllers.control.prepareForOffline(),
        // },
      );

  @override
  FutureOr<void> processOfflineData(OfflineMemoryData offlineData) {}
}
