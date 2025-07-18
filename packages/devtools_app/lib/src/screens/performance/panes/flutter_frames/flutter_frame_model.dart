// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import '../../../../shared/primitives/utils.dart';
import '../../performance_model.dart';
import '../controls/enhance_tracing/enhance_tracing_model.dart';
import '../frame_analysis/frame_analysis_model.dart';

/// Data describing a single Flutter frame.
///
/// Each [FlutterFrame] should have 2 distinct pieces of data:
/// * `uiEventFlow` : flow of events showing the UI work for the frame.
/// * `rasterEventFlow` : flow of events showing the Raster work for the frame.
class FlutterFrame {
  FlutterFrame._({
    required this.id,
    required this.timeFromFrameTiming,
    required this.buildTime,
    required this.rasterTime,
    required this.vsyncOverheadTime,
  });

  factory FlutterFrame.fromJson(Map<String, Object?> json) {
    final frameTime = TimeRange.ofLength(
      start: json[startTimeKey]! as int,
      length: json[elapsedKey]! as int,
    );
    return FlutterFrame._(
      id: json[numberKey]! as int,
      timeFromFrameTiming: frameTime,
      buildTime: Duration(microseconds: json[buildKey]! as int),
      rasterTime: Duration(microseconds: json[rasterKey]! as int),
      vsyncOverheadTime: Duration(microseconds: json[vsyncOverheadKey]! as int),
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
  final TimeRange timeFromFrameTiming;

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
  final timelineEventData = FrameTimelineEventData();

  /// The [EnhanceTracingState] at the time that this frame object was created
  /// (e.g. when the 'Flutter.Frame' event for this frame was received).
  ///
  /// If we did not have [EnhanceTracingState] information at the time that this
  /// frame was drawn (e.g. the DevTools performance page was not opened and
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
    final duration = shaderEvents.fold<Duration>(Duration.zero, (
      previous,
      event,
    ) {
      return previous + event.time.duration;
    });
    return _shaderTime = duration;
  }

  Duration? _shaderTime;

  bool get hasShaderTime =>
      timelineEventData.rasterEvent != null && shaderDuration != Duration.zero;

  void setEventFlow(FlutterTimelineEvent event) {
    timelineEventData.setEventFlow(event: event);
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

  Map<String, Object?> get json => {
    numberKey: id,
    startTimeKey: timeFromFrameTiming.start,
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

  String toStringVerbose() {
    final buf = StringBuffer();
    buf.writeln('UI timeline event for frame $id:');
    timelineEventData.uiEvent?.format(buf, '  ');
    buf.writeln('\nUI trace for frame $id');
    timelineEventData.uiEvent?.writeTrackEventsToBuffer(buf);
    buf.writeln('\nRaster timeline event frame $id:');
    timelineEventData.rasterEvent?.format(buf, '  ');
    buf.writeln('\nRaster trace for frame $id');
    timelineEventData.rasterEvent?.writeTrackEventsToBuffer(buf);
    return buf.toString();
  }

  FlutterFrame shallowCopy() {
    return FlutterFrame.fromJson(json);
  }
}

class FrameTimelineEventData {
  /// Events describing the UI work for a [FlutterFrame].
  FlutterTimelineEvent? get uiEvent => _eventFlows[TimelineEventType.ui.index];

  /// Events describing the Raster work for a [FlutterFrame].
  FlutterTimelineEvent? get rasterEvent =>
      _eventFlows[TimelineEventType.raster.index];

  // ignore: avoid-explicit-type-declaration, necessary here.
  final List<FlutterTimelineEvent?> _eventFlows = List.generate(2, (_) => null);

  bool get wellFormed => uiEvent != null && rasterEvent != null;

  bool get isNotEmpty => uiEvent != null || rasterEvent != null;

  void setEventFlow({required FlutterTimelineEvent event}) {
    final type = event.type!;
    _eventFlows[type.index] = event;
  }

  FlutterTimelineEvent? eventByType(TimelineEventType type) {
    if (type == TimelineEventType.ui) return uiEvent;
    if (type == TimelineEventType.raster) return rasterEvent;
    return null;
  }
}
