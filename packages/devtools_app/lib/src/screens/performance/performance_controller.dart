// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:pedantic/pedantic.dart';

import '../../config_specific/import_export/import_export.dart';
import '../../primitives/auto_dispose.dart';
import '../../shared/globals.dart';
import 'panes/controls/enhance_tracing/enhance_tracing_controller.dart';
import 'panes/flutter_frames/flutter_frame_model.dart';
import 'panes/flutter_frames/flutter_frames_controller.dart';
import 'panes/raster_stats/raster_stats_controller.dart';
import 'panes/timeline_events/timeline_events_controller.dart';
import 'performance_model.dart';
import 'performance_screen.dart';
import 'rebuild_counts.dart';

/// This class contains the business logic for [performance_screen.dart].
///
/// The controller manages the performance data model and feature controllers,
/// which handle things like data processing and communication with the view
/// to give and receive data updates.
class PerformanceController extends DisposableController
    with AutoDisposeControllerMixin {
  PerformanceController() {
    flutterFramesController = FlutterFramesController(this);
    timelineEventsController = TimelineEventsController(this);
    rasterStatsController = RasterStatsController(this);
    _featureControllers = [
      flutterFramesController,
      timelineEventsController,
      rasterStatsController,
    ];
    // See https://github.com/dart-lang/linter/issues/3801
    // ignore: discarded_futures
    unawaited(_init());
  }

  late final FlutterFramesController flutterFramesController;

  late final TimelineEventsController timelineEventsController;

  late final RasterStatsController rasterStatsController;

  late List<PerformanceFeatureController> _featureControllers;

  // TODO(jacobr): add the recount controller to [_featureControllers] once your
  // PR for rebuild indicators lands
  //(https://github.com/flutter/devtools/pull/4566).
  final rebuildCountModel = RebuildCountModel();

  final enhanceTracingController = EnhanceTracingController();

  final _exportController = ExportController();

  /// Active timeline data.
  ///
  /// This is the true source of data for the UI. In the case of an offline
  /// import, this will begin as a copy of [offlinePerformanceData] (the original
  /// data from the imported file). If any modifications are made while the data
  /// is displayed (e.g. change in selected timeline event, selected frame,
  /// etc.), those changes will be tracked here.
  PerformanceData? data;

  /// Timeline data loaded via import.
  ///
  /// This is expected to be null when we are not in [offlineController.offlineMode].
  ///
  /// This will contain the original data from the imported file, regardless of
  /// any selection modifications that occur while the data is displayed. [data]
  /// will start as a copy of offlineTimelineData in this case, and will track
  /// any data modifications that occur while the data is displayed (e.g. change
  /// in selected timeline event, selected frame, etc.).
  PerformanceData? offlinePerformanceData;

  late final Future<void> _initialized;

  Future<void> get initialized => _initialized;

  Future<void> _init() {
    return _initialized = _initHelper();
  }

  Future<void> _initHelper() async {
    initData();
    await _applyToFeatureControllersAsync((c) => c.init());
    if (!offlineController.offlineMode.value) {
      await serviceManager.onServiceAvailable;

      enhanceTracingController.init();

      // Listen for Flutter.Frame events with frame timing data.
      // Listen for Flutter.RebuiltWidgets events.
      autoDisposeStreamSubscription(
        serviceManager.service!.onExtensionEventWithHistory.listen((event) {
          if (event.extensionKind == 'Flutter.Frame') {
            final frame = FlutterFrame.parse(event.extensionData!.data);
            enhanceTracingController.assignStateForFrame(frame);
            flutterFramesController.addFrame(frame);
          } else if (event.extensionKind == 'Flutter.RebuiltWidgets') {
            rebuildCountModel.processRebuildEvent(event.extensionData!.data);
          }
        }),
      );
    }
  }

  void initData() {
    data ??= PerformanceData();
  }

  /// Calls [callback] for each feature controller in [_featureControllers].
  ///
  /// [callback] can return a [Future] or a [FutureOr]
  void _applyToFeatureControllers(
    void Function(PerformanceFeatureController) callback,
  ) {
    _featureControllers.forEach(callback);
  }

  /// Calls [callback] for each feature controller in [_featureControllers].
  ///
  /// [callback] can return a [Future] or a [FutureOr]
  Future<void> _applyToFeatureControllersAsync(
    FutureOr<void> Function(PerformanceFeatureController) callback,
  ) async {
    Future<void> _helper(
      FutureOr<void> Function(PerformanceFeatureController) futureOr,
      PerformanceFeatureController controller,
    ) async {
      await futureOr(controller);
    }

    final futures = <Future<void>>[];
    for (final controller in _featureControllers) {
      futures.add(_helper(callback, controller));
    }
    await Future.wait(futures);
  }

  Future<void> setActiveFeature(
    PerformanceFeatureController? featureController,
  ) async {
    await _applyToFeatureControllersAsync(
      (c) async => await c.setIsActiveFeature(
        featureController != null && c == featureController,
      ),
    );
  }

  FutureOr<void> processOfflineData(OfflinePerformanceData offlineData) async {
    await clearData();
    offlinePerformanceData = offlineData.shallowClone();
    data = offlineData.shallowClone();

    await _applyToFeatureControllersAsync(
      (c) => c.setOfflineData(offlinePerformanceData!),
    );
  }

  /// Exports the current performance screen data to a .json file.
  ///
  /// This method returns the name of the file that was downloaded.
  String exportData() {
    final encodedData =
        _exportController.encode(PerformanceScreen.id, data!.json);
    return _exportController.downloadFile(encodedData);
  }

  /// Clears the timeline data currently stored by the controller as well the
  /// VM timeline if a connected app is present.
  Future<void> clearData() async {
    if (serviceManager.connectedAppInitialized) {
      await serviceManager.service!.clearVMTimeline();
    }
    offlinePerformanceData = null;
    data?.clear();
    serviceManager.errorBadgeManager.clearErrors(PerformanceScreen.id);
    await _applyToFeatureControllersAsync((c) => c.clearData());
  }

  @override
  void dispose() {
    _applyToFeatureControllers((c) => c.dispose());
    enhanceTracingController.dispose();
    super.dispose();
  }
}

abstract class PerformanceFeatureController extends DisposableController {
  PerformanceFeatureController(this.performanceController);

  final PerformanceController performanceController;

  PerformanceData? get data => performanceController.data;

  /// Whether this feature is active and visible to the user.
  bool get isActiveFeature => _isActiveFeature;
  bool _isActiveFeature = false;

  Future<void> setIsActiveFeature(bool value) async {
    _isActiveFeature = value;
    if (value) {
      await onBecomingActive();
    }
  }

  Future<void> onBecomingActive() async {}

  Future<void> init() async {}

  FutureOr<void> setOfflineData(PerformanceData offlineData);

  FutureOr<void> clearData();

  void handleSelectedFrame(FlutterFrame frame);
}
