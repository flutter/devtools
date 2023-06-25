// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import '../../../../shared/primitives/trace_event.dart';
import '../../../../shared/primitives/utils.dart';
import '../../performance_model.dart';
import '../controls/enhance_tracing/enhance_tracing_model.dart';
import '../frame_analysis/frame_analysis_model.dart';

/// Data describing a single Flutter frame.
///
/// Each [FlutterFrame] should have 2 distinct pieces of data:
/// * [uiEventFlow] : flow of events showing the UI work for the frame.
/// * [rasterEventFlow] : flow of events showing the Raster work for the frame.
class FlutterFrame {
  FlutterFrame._({
    required this.id,
    required this.timeFromFrameTiming,
    required this.buildTime,
    required this.rasterTime,
    required this.vsyncOverheadTime,
  });

  factory FlutterFrame.parse(Map<String, dynamic> json) {
    final timeStart = Duration(microseconds: json[startTimeKey]!);
    final timeEnd = timeStart + Duration(microseconds: json[elapsedKey]!);
    final frameTime = TimeRange()
      ..start = timeStart
      ..end = timeEnd;
    return FlutterFrame._(
      id: json[numberKey]!,
      timeFromFrameTiming: frameTime,
      buildTime: Duration(microseconds: json[buildKey]!),
      rasterTime: Duration(microseconds: json[rasterKey]!),
      vsyncOverheadTime: Duration(microseconds: json[vsyncOverheadKey]!),
    );
  }

  static const numberKey = 'number';

  static const buildKey = 'build';

  static const rasterKey = 'raster';

  static const vsyncOverheadKey = 'vsyncOverhead';

  static const startTimeKey = 'startTime';

  static const elapsedKey = 'elapsed';

  /// Id for this Flutter frame, originally created in the Flutter engine.
  final int id;

  /// The time range of the Flutter frame based on the FrameTiming API from
  /// which the data was parsed.
  ///
  /// This will not match the timestamps on the VM timeline. For activities
  /// involving the VM timeline, use [timeFromEventFlows] instead.
  final TimeRange timeFromFrameTiming;

  /// The time range of the Flutter frame based on the frame's
  /// [timelineEventData], which contains timing information from the VM's
  /// timeline events.
  ///
  /// This time range should be used for activities related to timeline events,
  /// like scrolling a frame's timeline events into view, for example.
  TimeRange get timeFromEventFlows => timelineEventData.time;

  /// Build time for this Flutter frame based on data from the FrameTiming API
  /// sent over the extension stream as 'Flutter.Frame' events.
  final Duration buildTime;

  /// Raster time for this Flutter frame based on data from the FrameTiming API
  /// sent over the extension stream as 'Flutter.Frame' events.
  final Duration rasterTime;

  /// Vsync overhead time for this Flutter frame based on data from the
  /// FrameTiming API sent over the extension stream as 'Flutter.Frame' events.
  final Duration vsyncOverheadTime;

  /// Timeline event data for this [FlutterFrame].
  final FrameTimelineEventData timelineEventData = FrameTimelineEventData();

  /// The [EnhanceTracingState] at the time that this frame object was created
  /// (e.g. when the 'Flutter.Frame' event for this frame was received).
  ///
  /// If we did not have [EnhanceTracingState] information at the time that this
  /// frame was drawn (e.g. the DevTools performancd page was not opened and
  /// listening for frames yet), this value will be null.
  EnhanceTracingState? enhanceTracingState;

  FrameAnalysis? get frameAnalysis {
    final frameAnalysis_ = _frameAnalysis;
    if (frameAnalysis_ != null) return frameAnalysis_;
    if (timelineEventData.isNotEmpty) {
      return _frameAnalysis = FrameAnalysis(this);
    }
    return null;
  }

  FrameAnalysis? _frameAnalysis;

  bool get isWellFormed => timelineEventData.wellFormed;

  Duration get shaderDuration {
    if (_shaderTime != null) return _shaderTime!;
    if (timelineEventData.rasterEvent == null) return Duration.zero;
    final shaderEvents = timelineEventData.rasterEvent!
        .shallowNodesWithCondition((event) => event.isShaderEvent);
    final duration =
        shaderEvents.fold<Duration>(Duration.zero, (previous, event) {
      return previous + event.time.duration;
    });
    return _shaderTime = duration;
  }

  Duration? _shaderTime;

  bool get hasShaderTime =>
      timelineEventData.rasterEvent != null && shaderDuration != Duration.zero;

  void setEventFlow(SyncTimelineEvent event, {TimelineEventType? type}) {
    type ??= event.type;
    timelineEventData.setEventFlow(event: event, type: type);
    event.frameId = id;
  }

  bool isJanky(double displayRefreshRate) {
    return isUiJanky(displayRefreshRate) || isRasterJanky(displayRefreshRate);
  }

  bool isUiJanky(double displayRefreshRate) {
    return buildTime.inMilliseconds > _targetMsPerFrame(displayRefreshRate);
  }

  bool isRasterJanky(double displayRefreshRate) {
    return rasterTime.inMilliseconds > _targetMsPerFrame(displayRefreshRate);
  }

  bool hasShaderJank(double displayRefreshRate) {
    final quarterFrame = (_targetMsPerFrame(displayRefreshRate) / 4).round();
    return isRasterJanky(displayRefreshRate) &&
        hasShaderTime &&
        shaderDuration > Duration(milliseconds: quarterFrame);
  }

  double _targetMsPerFrame(double displayRefreshRate) {
    return 1 / displayRefreshRate * 1000;
  }

  Map<String, dynamic> get json => {
        numberKey: id,
        startTimeKey: timeFromFrameTiming.start!.inMicroseconds,
        elapsedKey: timeFromFrameTiming.duration.inMicroseconds,
        buildKey: buildTime.inMicroseconds,
        rasterKey: rasterTime.inMicroseconds,
        vsyncOverheadKey: vsyncOverheadTime.inMicroseconds,
      };

  @override
  String toString() {
    return 'Frame $id - $timeFromFrameTiming, '
        'ui: ${timelineEventData.uiEvent?.time}, '
        'raster: ${timelineEventData.rasterEvent?.time}';
  }

  FlutterFrame shallowCopy() {
    return FlutterFrame.parse(json);
  }
}

class FrameTimelineEventData {
  /// Events describing the UI work for a [FlutterFrame].
  SyncTimelineEvent? get uiEvent => _eventFlows[TimelineEventType.ui.index];

  /// Events describing the Raster work for a [FlutterFrame].
  SyncTimelineEvent? get rasterEvent =>
      _eventFlows[TimelineEventType.raster.index];

  final List<SyncTimelineEvent?> _eventFlows = List.generate(2, (_) => null);

  bool get wellFormed => uiEvent != null && rasterEvent != null;

  bool get isNotEmpty => uiEvent != null || rasterEvent != null;

  final time = TimeRange();

  void setEventFlow({
    required SyncTimelineEvent event,
    required TimelineEventType type,
    bool setTimeData = true,
  }) {
    _eventFlows[type.index] = event;
    if (setTimeData) {
      if (type == TimelineEventType.ui) {
        time.start = event.time.start;
        // If [rasterEventFlow] has already completed, set the end time for this
        // frame to [event]'s end time.
        if (rasterEvent != null) {
          time.end = event.time.end;
        }
      } else if (type == TimelineEventType.raster) {
        // If [uiEventFlow] is null, that means that this raster event flow
        // completed before the ui event flow did for this frame. This means one
        // of two things: 1) there will never be a [uiEventFlow] for this frame
        // because the UI events are not present in the available timeline
        // events, or 2) the [uiEventFlow] has started but not completed yet. In
        // the event that 2) is true, do not set the frame end time here because
        // the end time for this frame will be set to the end time for
        // [uiEventFlow] once it finishes.
        final theUiEvent = uiEvent;
        if (theUiEvent != null) {
          time.end = Duration(
            microseconds: math.max(
              theUiEvent.time.end!.inMicroseconds,
              event.time.end?.inMicroseconds ?? 0,
            ),
          );
        }
      }
    }
  }

  SyncTimelineEvent? eventByType(TimelineEventType type) {
    if (type == TimelineEventType.ui) return uiEvent;
    if (type == TimelineEventType.raster) return rasterEvent;
    return null;
  }
}
