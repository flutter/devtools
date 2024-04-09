// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../../devtools_app.dart';
import '../../../shared/memory/class_name.dart';
import '../../../shared/memory/heap_graph_loader.dart';
import '../panes/chart/controller/chart_pane_controller.dart';
import '../panes/control/controller/control_pane_controller.dart';
import '../panes/diff/controller/diff_pane_controller.dart';
import '../panes/profile/profile_pane_controller.dart';
import '../panes/tracing/tracing_pane_controller.dart';
import 'offline_data/offline_data.dart';

/// This class contains the business logic for memory screen.
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
    @visibleForTesting DiffPaneController? connectedDiff,
    @visibleForTesting ProfilePaneController? connectedProfile,
  }) {
    if (connectedDiff != null && connectedProfile != null) {
      _mode = DevToolsMode.connected;
    } else {
      _mode = devToolsMode;
    }
    unawaited(_init(connectedDiff, connectedProfile));
  }

  late final DevToolsMode _mode;

  ValueNotifier<bool> isInitialized = ValueNotifier(false);

  /// Index of the selected feature tab.
  ///
  /// This value is used to set the initial tab selection of the
  /// [MemoryTabView]. This widget will be disposed and re-initialized on
  /// DevTools screen changes, so we must store this value in the controller
  /// instead of the widget state.
  int selectedFeatureTabIndex = 0;

  late final DiffPaneController diff;

  late final ProfilePaneController profile;

  late final MemoryChartPaneController chart;

  late final TracingPaneController tracing;

  late final MemoryControlPaneController control;

  @override
  void dispose() {
    super.dispose();
    HeapClassName.dispose();
    chart.dispose();
    tracing.dispose();
    diff.dispose();
    profile.dispose();
  }

  Future<void> _init(
    @visibleForTesting DiffPaneController? connectedDiff,
    @visibleForTesting ProfilePaneController? connectedProfile,
  ) async {
    assert(!isInitialized.value);
    switch (_mode) {
      case DevToolsMode.disconnected:
        throw StateError('Memory screen does not support disconnected mode.');
      case DevToolsMode.connected:
        _initializeData(
          diffPaneController: connectedDiff,
          profilePaneController: connectedProfile,
        );
      case DevToolsMode.offlineData:
        assert(connectedDiff == null && connectedProfile == null);
        await maybeLoadOfflineData(
          PerformanceScreen.id,
          createData: (json) => OfflineMemoryData.parse(json),
          shouldLoad: (data) => !data.isEmpty,
        );
        // If shouldLoad returns false, previous line is noop, so data should be initialized.
        if (!isInitialized.value) _initializeData();
    }
    assert(isInitialized.value);
  }

  void _initializeData({
    OfflineMemoryData? offlineData,
    @visibleForTesting DiffPaneController? diffPaneController,
    @visibleForTesting ProfilePaneController? profilePaneController,
  }) {
    assert(!isInitialized.value);

    chart = offlineData?.chart ?? MemoryChartPaneController(_mode);
    diff = diffPaneController ??
        offlineData?.diff ??
        DiffPaneController(
          loader: HeapGraphLoaderRuntime(chart.memoryTimeline),
        );
    profile = profilePaneController ??
        offlineData?.profile ??
        ProfilePaneController();
    control = MemoryControlPaneController(
      chart.memoryTimeline,
      exportData: exportData,
    );
    tracing = TracingPaneController();
    selectedFeatureTabIndex =
        offlineData?.selectedTab ?? selectedFeatureTabIndex;
    if (offlineData != null) profile.setFilter(offlineData.filter);
    _shareClassFilterBetweenProfileAndDiff();

    isInitialized.value = true;
  }

  @override
  OfflineScreenData prepareOfflineScreenData() => OfflineScreenData(
        screenId: ScreenMetaData.memory.id,
        data: OfflineMemoryData(
          diff,
          profile,
          chart,
          profile.classFilter.value,
          selectedTab: selectedFeatureTabIndex,
        ).prepareForOffline(),
      );

  @override
  FutureOr<void> processOfflineData(OfflineMemoryData offlineData) {
    assert(!isInitialized.value);
    _initializeData(offlineData: offlineData);
  }

  void _shareClassFilterBetweenProfileAndDiff() {
    diff.derived.applyFilter(profile.classFilter.value);

    profile.classFilter.addListener(() {
      diff.derived.applyFilter(profile.classFilter.value);
    });

    diff.core.classFilter.addListener(() {
      profile.setFilter(
        diff.core.classFilter.value,
      );
    });
  }
}
