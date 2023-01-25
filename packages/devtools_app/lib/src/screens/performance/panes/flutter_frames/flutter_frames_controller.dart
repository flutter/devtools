// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../../../service/service_manager.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/primitives/trace_event.dart';
import '../../../../shared/primitives/utils.dart';
import '../../performance_controller.dart';
import '../../performance_model.dart';
import '../../performance_screen.dart';
import 'flutter_frame_model.dart';

class FlutterFramesController extends PerformanceFeatureController {
  FlutterFramesController(super.performanceController);

  /// The currently selected timeline frame.
  ValueListenable<FlutterFrame?> get selectedFrame => _selectedFrameNotifier;
  final _selectedFrameNotifier = ValueNotifier<FlutterFrame?>(null);

  /// The flutter frames in the chart.
  ValueListenable<List<FlutterFrame>> get flutterFrames => _flutterFrames;
  final _flutterFrames = ListValueNotifier<FlutterFrame>([]);

  /// Whether we should show the Flutter frames chart.
  ValueListenable<bool> get showFlutterFramesChart => _showFlutterFramesChart;
  final _showFlutterFramesChart = ValueNotifier<bool>(true);
  void toggleShowFlutterFrames(bool value) {
    _showFlutterFramesChart.value = value;
    unawaited(setIsActiveFeature(_showFlutterFramesChart.value));
  }

  /// Whether flutter frames are currently being recorded.
  ValueListenable<bool> get recordingFrames => _recordingFrames;
  final _recordingFrames = ValueNotifier<bool>(true);

  /// Whether the main 'Performance' tab should be badged with a count of the
  /// janky Flutter frames present in the Flutter frames chart.
  ValueListenable<bool> get badgeTabForJankyFrames => _badgeTabForJankyFrames;
  final _badgeTabForJankyFrames = ValueNotifier<bool>(false);

  /// The display refresh rate for the connected device.
  ///
  /// This value is determined by device hardware, and we query it from the
  /// Flutter engine.
  ValueListenable<double> get displayRefreshRate => _displayRefreshRate;
  final _displayRefreshRate = ValueNotifier<double>(defaultRefreshRate);

  /// Frames that have been recorded but not shown because the flutter frame
  /// recording has been paused.
  final _pendingFlutterFrames = <FlutterFrame>[];

  /// The collection of Flutter frames that have not yet been linked to their
  /// respective [TimelineEvent]s for the UI and Raster thread.
  ///
  /// These [FlutterFrame]s are keyed by the Flutter frame ID that matches the
  /// frame id in the corresponding [TimelineEvent]s.
  final _unassignedFlutterFrames = <int, FlutterFrame>{};

  /// Tracks the current frame undergoing selection so that we can equality
  /// check after async operations and bail out early if another frame has been
  /// selected during awaits.
  FlutterFrame? currentFrameBeingSelected;

  @override
  Future<void> init() async {
    if (!offlineController.offlineMode.value) {
      await serviceManager.onServiceAvailable;
      final connectedApp = serviceManager.connectedApp!;
      if (connectedApp.isFlutterAppNow!) {
        // Default to true for profile builds only.
        _badgeTabForJankyFrames.value = await connectedApp.isProfileBuild;

        final refreshRate = connectedApp.isFlutterAppNow!
            ? await serviceManager.queryDisplayRefreshRate
            : defaultRefreshRate;

        _displayRefreshRate.value = refreshRate ?? defaultRefreshRate;
        data?.displayRefreshRate = _displayRefreshRate.value;
      }
    }
  }

  // We override this for [FlutterFramesController] because this feature's
  // "active" state will be determined by different parameters from other
  // feature controllers, which respond to tab switches.
  @override
  Future<void> setIsActiveFeature(bool value) async {
    final isFlutterApp = serviceManager.connectedApp?.isFlutterAppNow ?? false;
    value = isFlutterApp && _showFlutterFramesChart.value;
    await super.setIsActiveFeature(value);
  }

  void addFrame(FlutterFrame frame) {
    _assignEventsToFrame(frame);
    if (_recordingFrames.value) {
      if (_pendingFlutterFrames.isNotEmpty) {
        _addPendingFlutterFrames();
      }
      _maybeBadgeTabForJankyFrame(frame);
      data!.frames.add(frame);
      _flutterFrames.add(frame);
    } else {
      _pendingFlutterFrames.add(frame);
    }
  }

  void _assignEventsToFrame(FlutterFrame frame) {
    performanceController.timelineEventsController
        .maybeAddUnassignedEventsToFrame(frame);
    if (frame.isWellFormed) {
      _updateFirstWellFormedFrameMicros(frame);
    } else {
      _unassignedFlutterFrames[frame.id] = frame;
    }
  }

  void assignEventToFrame(
    int? frameNumber,
    SyncTimelineEvent event,
    TimelineEventType type,
  ) {
    assert(frameNumber != null && hasUnassignedFlutterFrame(frameNumber));
    final frame = _unassignedFlutterFrames[frameNumber]!;
    frame.setEventFlow(event, type: type);
    if (frame.isWellFormed) {
      _unassignedFlutterFrames.remove(frameNumber);
      _updateFirstWellFormedFrameMicros(frame);
    }
  }

  bool hasUnassignedFlutterFrame(int frameNumber) {
    return _unassignedFlutterFrames.containsKey(frameNumber);
  }

  void _addPendingFlutterFrames() {
    _pendingFlutterFrames.forEach(_maybeBadgeTabForJankyFrame);
    data!.frames.addAll(_pendingFlutterFrames);
    _flutterFrames.addAll(_pendingFlutterFrames);
    _pendingFlutterFrames.clear();
  }

  void _maybeBadgeTabForJankyFrame(FlutterFrame frame) {
    if (_badgeTabForJankyFrames.value) {
      if (frame.isJanky(_displayRefreshRate.value)) {
        serviceManager.errorBadgeManager
            .incrementBadgeCount(PerformanceScreen.id);
      }
    }
  }

  void toggleRecordingFrames(bool recording) {
    _recordingFrames.value = recording;
    if (recording) {
      _addPendingFlutterFrames();
    }
  }

  /// Timestamp in micros of the first well formed frame, or in other words,
  /// the first frame for which we have timeline event data.
  int? firstWellFormedFrameMicros;

  void _updateFirstWellFormedFrameMicros(FlutterFrame frame) {
    assert(frame.isWellFormed);
    firstWellFormedFrameMicros = math.min(
      firstWellFormedFrameMicros ?? maxJsInt,
      frame.timeFromFrameTiming.start!.inMicroseconds,
    );
  }

  @override
  void clearData() {
    _flutterFrames.clear();
    _unassignedFlutterFrames.clear();
    firstWellFormedFrameMicros = null;
    _selectedFrameNotifier.value = null;
  }

  @override
  void handleSelectedFrame(FlutterFrame frame) {
    if (data == null) {
      return;
    }
    final _data = data!;

    currentFrameBeingSelected = frame;

    // Unselect [frame] if is already selected.
    if (_data.selectedFrame == frame) {
      _data.selectedFrame = null;
      _selectedFrameNotifier.value = null;
      return;
    }

    _data.selectedFrame = frame;
    _selectedFrameNotifier.value = frame;

    // We do not need to block the UI on the TimelineEvents feature loading the
    // selected frame.
    unawaited(
      performanceController.timelineEventsController.handleSelectedFrame(frame),
    );
  }

  @override
  Future<void> setOfflineData(PerformanceData offlineData) async {
    offlineData.frames.forEach(_assignEventsToFrame);
    _flutterFrames
      ..clear()
      ..addAll(offlineData.frames);
    final frameToSelect = offlineData.frames.firstWhereOrNull(
      (frame) => frame.id == offlineData.selectedFrameId,
    );
    if (frameToSelect != null) {
      performanceController.data!.selectedFrame = frameToSelect;
      _selectedFrameNotifier.value = frameToSelect;
    }

    _displayRefreshRate.value = offlineData.displayRefreshRate;
  }

  @override
  void onBecomingActive() {}
}
