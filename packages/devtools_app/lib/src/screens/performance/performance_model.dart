// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../service/service_manager.dart';
import '../../shared/primitives/trees.dart';
import '../../shared/primitives/utils.dart';
import 'panes/flutter_frames/flutter_frame_model.dart';
import 'panes/rebuild_stats/rebuild_stats_model.dart';
import 'panes/timeline_events/perfetto/tracing/model.dart';

class OfflinePerformanceData {
  OfflinePerformanceData({
    this.perfettoTraceBinary,
    this.frames = const <FlutterFrame>[],
    this.selectedFrame,
    this.rebuildCountModel,
    double? displayRefreshRate,
  }) : displayRefreshRate = displayRefreshRate ?? defaultRefreshRate;

  factory OfflinePerformanceData.fromJson(Map<String, Object?> json_) {
    final json = _PerformanceDataJson(json_);

    final selectedFrameId = json.selectedFrameId;
    final frames = json.frames;
    final selectedFrame = frames.firstWhereOrNull(
      (frame) => frame.id == selectedFrameId,
    );

    return OfflinePerformanceData(
      perfettoTraceBinary: json.traceBinary,
      frames: frames,
      selectedFrame: selectedFrame,
      rebuildCountModel: json.rebuildCountModel,
      displayRefreshRate: json.displayRefreshRate,
    );
  }

  static const traceBinaryKey = 'traceBinary';
  static const rebuildCountModelKey = 'rebuildCountModel';
  static const displayRefreshRateKey = 'displayRefreshRate';
  static const flutterFramesKey = 'flutterFrames';
  static const selectedFrameIdKey = 'selectedFrameId';

  final Uint8List? perfettoTraceBinary;

  final RebuildCountModel? rebuildCountModel;

  final double displayRefreshRate;

  /// All frames currently visible in the Performance page.
  final List<FlutterFrame> frames;

  final FlutterFrame? selectedFrame;

  bool get isEmpty => perfettoTraceBinary == null;

  Map<String, Object?> toJson() => {
    traceBinaryKey: perfettoTraceBinary,
    flutterFramesKey: frames.map((frame) => frame.json).toList(),
    selectedFrameIdKey: selectedFrame?.id,
    displayRefreshRateKey: displayRefreshRate,
    rebuildCountModelKey: rebuildCountModel?.toJson(),
  };
}

extension type _PerformanceDataJson(Map<String, Object?> json) {
  Uint8List? get traceBinary {
    final value = (json[OfflinePerformanceData.traceBinaryKey] as List?)
        ?.cast<int>();
    return value == null ? null : Uint8List.fromList(value);
  }

  int? get selectedFrameId =>
      json[OfflinePerformanceData.selectedFrameIdKey] as int?;

  List<FlutterFrame> get frames =>
      (json[OfflinePerformanceData.flutterFramesKey] as List? ?? [])
          .cast<Map>()
          .map((f) => f.cast<String, Object?>())
          .map((f) => FlutterFrame.fromJson(f))
          .toList();

  double get displayRefreshRate =>
      (json[OfflinePerformanceData.displayRefreshRateKey] as num?)
          ?.toDouble() ??
      defaultRefreshRate;

  RebuildCountModel? get rebuildCountModel {
    final raw =
        (json[OfflinePerformanceData.rebuildCountModelKey] as Map? ?? {})
            .cast<String, Object?>();
    return raw.isNotEmpty ? RebuildCountModel.fromJson(raw) : null;
  }
}

class FlutterTimelineEvent extends TreeNode<FlutterTimelineEvent> {
  factory FlutterTimelineEvent(PerfettoTrackEvent firstTrackEvent) =>
      FlutterTimelineEvent._(
        trackEvents: [firstTrackEvent],
        type: firstTrackEvent.timelineEventType,
        timeBuilder: TimeRangeBuilder(start: firstTrackEvent.timestampMicros),
      );

  FlutterTimelineEvent._({
    required this.trackEvents,
    required this.type,
    required TimeRangeBuilder timeBuilder,
  }) : _timeBuilder = timeBuilder;

  static const rasterEventName = 'Rasterizer::DoDraw';
  static const uiEventName = 'Animator::BeginFrame';

  /// Perfetto track events associated with this [FlutterTimelineEvent].
  final List<PerfettoTrackEvent> trackEvents;

  final TimelineEventType? type;

  final TimeRangeBuilder _timeBuilder;

  /// The time range of this event.
  ///
  /// Throws if [isComplete] is false.
  TimeRange get time => _timeBuilder.build();

  /// Whether this event is complete and has received an end track event.
  bool get isComplete => _timeBuilder.canBuild;

  String? get name => trackEvents.first.name;

  int? get flutterFrameNumber => trackEvents.first.flutterFrameNumber;

  bool get isUiEvent => type == TimelineEventType.ui;
  bool get isRasterEvent => type == TimelineEventType.raster;
  bool get isShaderEvent =>
      trackEvents.first.isShaderEvent || trackEvents.last.isShaderEvent;

  void addEndTrackEvent(PerfettoTrackEvent event) {
    _timeBuilder.end = event.timestampMicros;
    trackEvents.add(event);
  }

  @override
  FlutterTimelineEvent shallowCopy() => FlutterTimelineEvent._(
    trackEvents: trackEvents.toList(),
    type: type,
    timeBuilder: _timeBuilder.copy(),
  );

  @visibleForTesting
  FlutterTimelineEvent deepCopy() {
    final copy = shallowCopy();
    copy.parent = parent;
    for (final child in children) {
      copy.addChild(child.deepCopy());
    }
    return copy;
  }

  @override
  String toString() {
    final buf = StringBuffer();
    format(buf, '  ');
    return buf.toString();
  }

  void writeTrackEventsToBuffer(StringBuffer buf) {
    final begin = trackEvents.first;
    final end = trackEvents.safeLast;
    buf.writeln(begin.toString());
    for (final child in children) {
      child.writeTrackEventsToBuffer(buf);
    }
    if (end != null) {
      buf.writeln(end.toString());
    }
  }

  void format(StringBuffer buf, String indent) {
    buf.write('$indent$name');
    if (isComplete) {
      buf.write(time);
    }

    buf.writeln(' ');
    for (final child in children) {
      child.format(buf, '  $indent');
    }
  }
}

enum TimelineEventType { ui, raster, other }
