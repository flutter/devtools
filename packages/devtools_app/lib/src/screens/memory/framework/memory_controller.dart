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
import '../shared/primitives/simple_elements.dart';
import 'offline_data/offline_data.dart';

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
    unawaited(_init(diffPaneController, profilePaneController));
  }

  ValueNotifier<bool> isInitialized = ValueNotifier(false);

  /// Mode of memory screen.
  ///
  /// Is detected at the time of initialization
  /// and does not change in lifetime of the controller.
  late final MemoryScreenMode mode;

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

  bool get _devToolsIsShowingOfflineData =>
      offlineDataController.showingOfflineData.value;

  Future<void> _init(
    @visibleForTesting DiffPaneController? diffPaneController,
    @visibleForTesting ProfilePaneController? profilePaneController,
  ) async {
    if (_devToolsIsShowingOfflineData) {
      assert(diffPaneController == null && profilePaneController == null);
      await _maybeInitOfflineDataMode();
      if (!isInitialized.value) await _initDisconnectedMode();
      assert(isInitialized.value);
      return;
    }
    await _initConnectedMode(diffPaneController, profilePaneController);
    assert(isInitialized.value);
  }

  Future<void> _maybeInitOfflineDataMode() async {
    assert(_devToolsIsShowingOfflineData);
    assert(!isInitialized.value);
    // Triggers [processOfflineData], that initializes all the controllers.
    await maybeLoadOfflineData(
      PerformanceScreen.id,
      createData: (json) => OfflineMemoryData.parse(json),
      shouldLoad: (data) => !data.isEmpty,
    );
  }

  Future<void> _initConnectedMode(
    @visibleForTesting DiffPaneController? diffPaneController,
    @visibleForTesting ProfilePaneController? profilePaneController,
  ) async {
    assert(!_devToolsIsShowingOfflineData);
    assert(!isInitialized.value);

    chart = MemoryChartPaneController();
    diff = diffPaneController ??
        DiffPaneController(
          loader: HeapGraphLoaderRuntime(chart.memoryTimeline),
        );
    profile = profilePaneController ?? ProfilePaneController();

    control = MemoryControlPaneController(
      chart.memoryTimeline,
      exportData: exportData,
    );
    tracing = TracingPaneController();

    _shareClassFilterBetweenProfileAndDiff();
    isInitialized.value = true;
  }

  Future<void> _initDisconnectedMode() async {
    assert(!_devToolsIsShowingOfflineData);
    assert(!isInitialized.value);
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
    assert(offlineDataController.showingOfflineData.value);
    assert(!isInitialized.value);
    diff = offlineData.diff;
    profile = offlineData.profile;
    chart = offlineData.chart;
    selectedFeatureTabIndex = offlineData.selectedTab;
    profile.setFilter(offlineData.filter);
    diff.derived.applyFilter(offlineData.filter);
    isInitialized.value = true;
  }

  void _shareClassFilterBetweenProfileAndDiff() {
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
}
