// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../shared/globals.dart';
import '../../../../shared/memory/class_name.dart';
import '../../../../shared/memory/heap_graph_loader.dart';
import '../../panes/chart/controller/chart_pane_controller.dart';
import '../../panes/chart/widgets/memory_android_chart.dart';
import '../../panes/chart/widgets/memory_events_pane.dart';
import '../../panes/chart/widgets/memory_vm_chart.dart';
import '../../panes/control/controller/control_pane_controller.dart';
import '../../panes/diff/controller/diff_pane_controller.dart';
import '../../panes/profile/profile_pane_controller.dart';
import '../../panes/tracing/tracing_pane_controller.dart';
import '../../shared/primitives/memory_timeline.dart';
import 'memory_tracker.dart';

class MemoryFeatureControllers {
  /// Controllers are passed for testability.
  MemoryFeatureControllers(
    DiffPaneController? diffPaneController,
    ProfilePaneController? profilePaneController, {
    required MemoryController? memoryController,
  }) {
    memoryTimeline = MemoryTimeline();
    diff = diffPaneController ?? _createDiffController();
    profile = profilePaneController ?? ProfilePaneController();

    final vmChartController = VMChartController(memoryController!);
    chart = MemoryChartPaneController(
      event: EventChartController(memoryController),
      vm: vmChartController,
      android: AndroidChartController(
        memoryController,
        sharedLabels: vmChartController.labelTimestamps,
      ),
    );
  }

  late DiffPaneController diff;
  late ProfilePaneController profile;
  late MemoryTimeline memoryTimeline;
  late MemoryChartPaneController chart;
  TracingPaneController tracing = TracingPaneController();
  MemoryControlPaneController control = MemoryControlPaneController();

  DiffPaneController _createDiffController() =>
      DiffPaneController(HeapGraphLoaderRuntime(memoryTimeline));

  void reset() {
    diff.dispose();
    diff = _createDiffController();

    profile.dispose();
    profile = ProfilePaneController();

    tracing.dispose();
    tracing = TracingPaneController();

    memoryTimeline.reset();
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

  void _handleConnectionStart() {
    if (controllers.chart.memoryTracker == null) {
      controllers.chart.memoryTracker =
          MemoryTracker(controllers.memoryTimeline, controllers.chart);
      controllers.chart.memoryTracker!.start();
    }

    // Log Flutter extension events.
    // Note: We do not need to listen to event history here because we do not
    // have matching historical data about total memory usage.
    autoDisposeStreamSubscription(
      serviceConnection.serviceManager.service!.onExtensionEvent
          .listen((Event event) {
        var extensionEventKind = event.extensionKind;
        String? customEventKind;
        if (MemoryTimeline.isCustomEvent(event.extensionKind!)) {
          extensionEventKind = MemoryTimeline.devToolsExtensionEvent;
          customEventKind =
              MemoryTimeline.customEventName(event.extensionKind!);
        }
        final jsonData = event.extensionData!.data.cast<String, Object>();
        // TODO(terry): Display events enabled in a settings page for now only these events.
        switch (extensionEventKind) {
          case 'Flutter.ImageSizesForFrame':
            controllers.memoryTimeline.addExtensionEvent(
              event.timestamp,
              event.extensionKind,
              jsonData,
            );
            break;
          case MemoryTimeline.devToolsExtensionEvent:
            controllers.memoryTimeline.addExtensionEvent(
              event.timestamp,
              MemoryTimeline.customDevToolsEvent,
              jsonData,
              customEventName: customEventKind,
            );
            break;
        }
      }),
    );

    autoDisposeStreamSubscription(
      controllers.chart.memoryTracker!.onChange.listen((_) {
        controllers.chart.memoryTrackerController
            .add(controllers.chart.memoryTracker);
      }),
    );
    autoDisposeStreamSubscription(
      controllers.chart.memoryTracker!.onChange.listen((_) {
        controllers.chart.memoryTrackerController
            .add(controllers.chart.memoryTracker);
      }),
    );

    // TODO(terry): Used to detect stream being closed from the
    // memoryController dispose method.  Needed when a HOT RELOAD
    // will call dispose however, initState doesn't seem
    // to happen David is working on scaffolding.
    controllers.chart.memoryTrackerController.stream.listen(
      (_) {},
      onDone: () {
        // Stop polling and reset memoryTracker.
        controllers.chart.memoryTracker?.stop();
        controllers.chart.memoryTracker = null;
      },
    );

    controllers.chart.updateAndroidChartVisibility();
    addAutoDisposeListener(
      preferences.memory.androidCollectionEnabled,
      controllers.chart.updateAndroidChartVisibility,
    );
  }

  /// This flag will be needed for offline mode implementation.
  bool offline = false;

  void _handleConnectionStop() {
    controllers.chart.memoryTracker?.stop();
    controllers.chart.memoryTrackerController
        .add(controllers.chart.memoryTracker);

    controllers.reset();
    controllers.chart.hasStopped = true;
  }

  void startTimeline() {
    addAutoDisposeListener(serviceConnection.serviceManager.connectedState, () {
      if (serviceConnection.serviceManager.connectedState.value.connected) {
        _handleConnectionStart();
      } else {
        _handleConnectionStop();
      }
    });

    if (serviceConnection.serviceManager.connectedAppInitialized) {
      _handleConnectionStart();
    }
  }

  @override
  void dispose() {
    super.dispose();
    unawaited(controllers.chart.memoryTrackerController.close());
    controllers.chart.memoryTracker?.dispose();
    controllers.dispose();
    HeapClassName.dispose();
  }
}
