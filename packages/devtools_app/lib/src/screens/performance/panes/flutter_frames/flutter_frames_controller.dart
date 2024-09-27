// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../../service/service_manager.dart';
import '../../../../shared/globals.dart';
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

  /// Controls the visibility of the Flutter frames chart.
  void toggleShowFlutterFrames(bool value) {
    preferences.performance.showFlutterFramesChart.value = value;
    unawaited(setIsActiveFeature(value));
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
    if (!offlineDataController.showingOfflineData.value) {
      await serviceConnection.serviceManager.onServiceAvailable;
      final connectedApp = serviceConnection.serviceManager.connectedApp!;
      if (connectedApp.isFlutterAppNow!) {
        // Default to true for profile builds only.
        _badgeTabForJankyFrames.value = await connectedApp.isProfileBuild;

        final refreshRate = connectedApp.isFlutterAppNow!
            ? await serviceConnection.queryDisplayRefreshRate
            : defaultRefreshRate;

        _displayRefreshRate.value = refreshRate ?? defaultRefreshRate;
      }
    }
  }

  // We override this for [FlutterFramesController] because this feature's
  // "active" state will be determined by different parameters from other
  // feature controllers, which respond to tab switches.
  @override
  Future<void> setIsActiveFeature(bool value) async {
    final isFlutterApp =
        serviceConnection.serviceManager.connectedApp?.isFlutterAppNow ?? false;
    final shouldShowFramesChart =
        preferences.performance.showFlutterFramesChart.value;
    value = isFlutterApp && shouldShowFramesChart;
    await super.setIsActiveFeature(value);
  }

  void addFrame(FlutterFrame frame) {
    _assignEventsToFrame(frame);
    if (_recordingFrames.value) {
      if (_pendingFlutterFrames.isNotEmpty) {
        _addPendingFlutterFrames();
      }
      _maybeBadgeTabForJankyFrame(frame);
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

  void assignEventToFrame(int? frameNumber, FlutterTimelineEvent event) {
    assert(frameNumber != null && hasUnassignedFlutterFrame(frameNumber));
    final frame = _unassignedFlutterFrames[frameNumber]!;
    frame.setEventFlow(event);
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
    _flutterFrames.addAll(_pendingFlutterFrames);
    _pendingFlutterFrames.clear();
  }

  void _maybeBadgeTabForJankyFrame(FlutterFrame frame) {
    if (_badgeTabForJankyFrames.value) {
      if (frame.isJanky(_displayRefreshRate.value)) {
        serviceConnection.errorBadgeManager
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
    currentFrameBeingSelected = frame;

    // Unselect [frame] if is already selected.
    if (_selectedFrameNotifier.value == frame) {
      _selectedFrameNotifier.value = null;
      return;
    }

    _selectedFrameNotifier.value = frame;

    // We do not need to block the UI on the TimelineEvents feature loading the
    // selected frame.
    unawaited(
      performanceController.timelineEventsController.handleSelectedFrame(frame),
    );
  }

  @override
  Future<void> setOfflineData(OfflinePerformanceData offlineData) async {
    offlineData.frames.forEach(_assignEventsToFrame);
    _flutterFrames
      ..clear()
      ..addAll(offlineData.frames);
    final frameToSelect = offlineData.frames.firstWhereOrNull(
      (frame) => frame.id == offlineData.selectedFrame?.id,
    );
    if (frameToSelect != null) {
      _selectedFrameNotifier.value = frameToSelect;
    }

    _displayRefreshRate.value = offlineData.displayRefreshRate;
  }

  @override
  void onBecomingActive() {}
}
