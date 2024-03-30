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
import '../../../../shared/utils.dart';
import '../../panes/chart/chart_pane_controller.dart';
import '../../panes/chart/memory_android_chart.dart';
import '../../panes/chart/memory_events_pane.dart';
import '../../panes/chart/memory_vm_chart.dart';
import '../../panes/diff/controller/diff_pane_controller.dart';
import '../../panes/profile/profile_pane_controller.dart';
import '../../panes/tracing/tracing_pane_controller.dart';
import '../../shared/primitives/memory_timeline.dart';
import 'memory_protocol.dart';

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

    final vmChartController = VMChartController(memoryController!); // !!!!!!!!
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
      memoryController: this, // !!!!!!!!
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

// --------------------------------

  String? get _isolateId =>
      serviceConnection.serviceManager.isolateManager.selectedIsolate.value?.id;

  final StreamController<MemoryTracker?> _memoryTrackerController =
      StreamController<MemoryTracker?>.broadcast();

  Stream<MemoryTracker?> get onMemory => _memoryTrackerController.stream;

  MemoryTracker? _memoryTracker;

  MemoryTracker? get memoryTracker => _memoryTracker;

  bool get hasStarted => _memoryTracker != null;

  bool hasStopped = false;

  void _handleIsolateChanged() {
    // TODO(terry): Need an event on the controller for this too?
  }

  void _handleConnectionStart() {
    if (_memoryTracker == null) {
      _memoryTracker = MemoryTracker(this);
      _memoryTracker!.start();
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
      _memoryTracker!.onChange.listen((_) {
        _memoryTrackerController.add(_memoryTracker);
      }),
    );
    autoDisposeStreamSubscription(
      _memoryTracker!.onChange.listen((_) {
        _memoryTrackerController.add(_memoryTracker);
      }),
    );

    // TODO(terry): Used to detect stream being closed from the
    // memoryController dispose method.  Needed when a HOT RELOAD
    // will call dispose however, initState doesn't seem
    // to happen David is working on scaffolding.
    _memoryTrackerController.stream.listen(
      (_) {},
      onDone: () {
        // Stop polling and reset memoryTracker.
        _memoryTracker?.stop();
        _memoryTracker = null;
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
    _memoryTracker?.stop();
    _memoryTrackerController.add(_memoryTracker);

    controllers.reset();
    hasStopped = true;
  }

  void startTimeline() {
    addAutoDisposeListener(
      serviceConnection.serviceManager.isolateManager.selectedIsolate,
      _handleIsolateChanged,
    );

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

  void stopTimeLine() {
    _memoryTracker?.stop();
  }

  bool get isGcing => _gcing;
  bool _gcing = false;

  Future<void> gc() async {
    _gcing = true;
    try {
      await serviceConnection.serviceManager.service!.getAllocationProfile(
        _isolateId!,
        gc: true,
      );
      notificationService.push('Successfully garbage collected.');
    } finally {
      _gcing = false;
    }
  }

  /// Detect stale isolates (sentineled), may happen after a hot restart.
  Future<bool> isIsolateLive(String isolateId) async {
    try {
      final service = serviceConnection.serviceManager.service!;
      await service.getIsolate(isolateId);
    } catch (e) {
      if (e is SentinelException) {
        final SentinelException sentinelErr = e;
        final message = 'isIsolateLive: Isolate sentinel $isolateId '
            '${sentinelErr.sentinel.kind}';
        debugLogger(message);
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    super.dispose();
    unawaited(_memoryTrackerController.close());
    _memoryTracker?.dispose();
    controllers.dispose();
    HeapClassName.dispose();
  }
}
