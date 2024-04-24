// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../shared/memory/class_name.dart';
import '../../../shared/memory/heap_graph_loader.dart';
import '../../../shared/offline_data.dart';
import '../../../shared/primitives/simple_items.dart';
import '../../../shared/screen.dart';
import '../../../shared/utils.dart';
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
    if (connectedDiff != null || connectedProfile != null) {
      _mode = DevToolsMode.connected;
    } else {
      _mode = devToolsMode;
    }
    unawaited(_init(connectedDiff, connectedProfile));
  }

  Future<void> get initialized => _initialized.future;
  final _initialized = Completer<void>();

  /// DevTools mode at the time of creation of the controller.
  ///
  /// DevTools will recreate controller when the mode changes.
  late final DevToolsMode _mode;

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

  static const _jsonKey = 'data';

  Future<void> _init(
    @visibleForTesting DiffPaneController? connectedDiff,
    @visibleForTesting ProfilePaneController? connectedProfile,
  ) async {
    assert(!_initialized.isCompleted);
    switch (_mode) {
      case DevToolsMode.disconnected:
        // TODO(polina-c): load memory screen in disconnected mode, https://github.com/flutter/devtools/issues/6972
        _initializeData();
      case DevToolsMode.connected:
        _initializeData(
          diffPaneController: connectedDiff,
          profilePaneController: connectedProfile,
        );
      case DevToolsMode.offlineData:
        assert(connectedDiff == null && connectedProfile == null);
        await maybeLoadOfflineData(
          ScreenMetaData.memory.id,
          createData: (json) {
            final data = json[_jsonKey];
            if (data is OfflineMemoryData) return data;
            return OfflineMemoryData.fromJson(data as Map<String, dynamic>);
          },
          shouldLoad: (data) => true,
          loadData: (data) async => _initializeData(offlineData: data),
        );
        // [maybeLoadOfflineData] will be a noop if there is no offline data for the memory screen,
        //  so ensure we still call [_initializedData] if it has not been called.
        if (!_initialized.isCompleted) _initializeData();
        assert(_initialized.isCompleted);
    }
    assert(_initialized.isCompleted);
  }

  void _initializeData({
    OfflineMemoryData? offlineData,
    @visibleForTesting DiffPaneController? diffPaneController,
    @visibleForTesting ProfilePaneController? profilePaneController,
  }) {
    assert(!_initialized.isCompleted);

    chart = offlineData?.chart ?? MemoryChartPaneController(_mode);
    diff = diffPaneController ??
        offlineData?.diff ??
        DiffPaneController(
          loader: HeapGraphLoaderRuntime(chart.data.timeline),
        );
    profile = profilePaneController ??
        offlineData?.profile ??
        ProfilePaneController();
    control = MemoryControlPaneController(
      chart.data.timeline,
      isChartVisible: chart.isChartVisible,
      exportData: exportData,
    );
    tracing = TracingPaneController();
    selectedFeatureTabIndex =
        offlineData?.selectedTab ?? selectedFeatureTabIndex;
    if (offlineData != null) profile.setFilter(offlineData.filter);
    _shareClassFilterBetweenProfileAndDiff();

    _initialized.complete();
  }

  @override
  OfflineScreenData prepareOfflineScreenData() => OfflineScreenData(
        screenId: ScreenMetaData.memory.id,
        data: {
          // Passing serializable data without conversion to json here
          // to skip serialization when data are passed in-process.
          _jsonKey: OfflineMemoryData(
            diff,
            profile,
            chart,
            profile.classFilter.value,
            selectedTab: selectedFeatureTabIndex,
          ),
        },
      );

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
