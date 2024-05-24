// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../shared/globals.dart';
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
      mode = ControllerCreationMode.connected;
    } else {
      mode = devToolsMode;
    }
    unawaited(_init(connectedDiff, connectedProfile));
  }

  Future<void> get initialized => _dataInitialized.future;
  final _dataInitialized = Completer<void>();

  /// DevTools mode at the time of creation of the controller.
  ///
  /// DevTools will recreate controller when the mode changes.
  late final ControllerCreationMode mode;

  /// Index of the selected feature tab.
  ///
  /// This value is used to set the initial tab selection of the
  /// [MemoryTabView]. This widget will be disposed and re-initialized on
  /// DevTools screen changes, so we must store this value in the controller
  /// instead of the widget state.
  int selectedFeatureTabIndex = 0;

  late final DiffPaneController diff;

  late final ProfilePaneController? profile;

  late final MemoryChartPaneController? chart;

  late final TracingPaneController? tracing;

  late final MemoryControlPaneController control;

  @override
  void dispose() {
    super.dispose();
    HeapClassName.dispose();
    chart?.dispose();
    tracing?.dispose();
    diff.dispose();
    profile?.dispose();
  }

  static const _jsonKey = 'data';

  Future<void> _init(
    @visibleForTesting DiffPaneController? connectedDiff,
    @visibleForTesting ProfilePaneController? connectedProfile,
  ) async {
    assert(!_dataInitialized.isCompleted);
    switch (mode) {
      case ControllerCreationMode.disconnected:
        // TODO(polina-c): load memory screen in disconnected mode, https://github.com/flutter/devtools/issues/6972
        _initializeData();
      case ControllerCreationMode.connected:
        await serviceConnection.serviceManager.onServiceAvailable;
        _initializeData(
          diffPaneController: connectedDiff,
          profilePaneController: connectedProfile,
        );
      case ControllerCreationMode.offlineData:
        assert(connectedDiff == null && connectedProfile == null);
        final loaded = await maybeLoadOfflineData(
          ScreenMetaData.memory.id,
          createData: (json) {
            final data = json[_jsonKey];
            if (data is OfflineMemoryData) return data;
            return OfflineMemoryData.fromJson(data as Map<String, dynamic>);
          },
          shouldLoad: (data) => true,
          loadData: (data) => _initializeData(offlineData: data),
        );
        // [maybeLoadOfflineData] will be a noop if there is no offline data for the memory screen,
        //  so ensure we still call [_initializedData] if it has not been called.
        assert(loaded == _dataInitialized.isCompleted);
        if (!_dataInitialized.isCompleted) {
          _initializeData();
        }
    }
    assert(_dataInitialized.isCompleted);
    assert(profile == null || profile!.rootPackage == diff.core.rootPackage);
  }

  void _initializeData({
    OfflineMemoryData? offlineData,
    @visibleForTesting DiffPaneController? diffPaneController,
    @visibleForTesting ProfilePaneController? profilePaneController,
  }) {
    assert(!_dataInitialized.isCompleted);

    final hasData = mode != ControllerCreationMode.disconnected;
    final isConnected = mode == ControllerCreationMode.connected;

    chart = hasData
        ? MemoryChartPaneController(mode, data: offlineData?.chart)
        : null;

    final rootPackage = isConnected
        ? serviceConnection.serviceManager.rootInfoNow().package!
        : null;

    diff = diffPaneController ??
        offlineData?.diff ??
        DiffPaneController(
          loader:
              isConnected ? HeapGraphLoaderRuntime(chart!.data.timeline) : null,
          rootPackage: rootPackage,
        );

    if (hasData) {
      profile = profilePaneController ??
          offlineData?.profile ??
          ProfilePaneController(
            mode: mode,
            rootPackage: rootPackage!,
          );
    } else {
      profile = null;
    }

    control = MemoryControlPaneController(
      chart?.data.timeline,
      mode,
      exportData: exportData,
    );

    tracing = hasData ? TracingPaneController(mode) : null;

    selectedFeatureTabIndex =
        offlineData?.selectedTab ?? selectedFeatureTabIndex;

    if (offlineData != null) profile?.setFilter(offlineData.filter);
    if (hasData) _shareClassFilterBetweenProfileAndDiff();

    _dataInitialized.complete();
  }

  @override
  OfflineScreenData prepareOfflineScreenData() {
    return OfflineScreenData(
      screenId: ScreenMetaData.memory.id,
      data: {
        // Passing serializable data without conversion to json here
        // to skip serialization when data is passed in-process.
        _jsonKey: OfflineMemoryData(
          diff,
          profile,
          chart?.data,
          diff.core.classFilter.value,
          selectedTab: selectedFeatureTabIndex,
        ),
      },
    );
  }

  void _shareClassFilterBetweenProfileAndDiff() {
    final theProfile = profile!;
    diff.derived.applyFilter(theProfile.classFilter.value);

    theProfile.classFilter.addListener(() {
      diff.derived.applyFilter(theProfile.classFilter.value);
    });

    diff.core.classFilter.addListener(() {
      theProfile.setFilter(
        diff.core.classFilter.value,
      );
    });
  }
}
