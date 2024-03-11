// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../service/service_manager.dart';
import '../../shared/primitives/trees.dart';
import '../../shared/primitives/utils.dart';
import 'panes/flutter_frames/flutter_frame_model.dart';
import 'panes/raster_stats/raster_stats_model.dart';
import 'panes/rebuild_stats/rebuild_stats_model.dart';
import 'panes/timeline_events/perfetto/tracing/model.dart';

class OfflinePerformanceData {
  OfflinePerformanceData({
    this.perfettoTraceBinary,
    this.frames = const <FlutterFrame>[],
    this.selectedFrame,
    this.rasterStats,
    this.rebuildCountModel,
    double? displayRefreshRate,
  }) : displayRefreshRate = displayRefreshRate ?? defaultRefreshRate;

  factory OfflinePerformanceData.parse(Map<String, Object?> json_) {
    final json = _PerformanceDataJson(json_);

    final selectedFrameId = json.selectedFrameId;
    final frames = json.frames;
    final selectedFrame =
        frames.firstWhereOrNull((frame) => frame.id == selectedFrameId);

    return OfflinePerformanceData(
      perfettoTraceBinary: json.traceBinary,
      frames: frames,
      selectedFrame: selectedFrame,
      rasterStats: json.rasterStats,
      rebuildCountModel: json.rebuildCountModel,
      displayRefreshRate: json.displayRefreshRate,
    );
  }

  static const traceBinaryKey = 'traceBinary';
  static const rasterStatsKey = 'rasterStats';
  static const rebuildCountModelKey = 'rebuildCountModel';
  static const displayRefreshRateKey = 'displayRefreshRate';
  static const flutterFramesKey = 'flutterFrames';
  static const selectedFrameIdKey = 'selectedFrameId';

  final Uint8List? perfettoTraceBinary;

  final RasterStats? rasterStats;

  final RebuildCountModel? rebuildCountModel;

  final double displayRefreshRate;

  /// All frames currently visible in the Performance page.
  final List<FlutterFrame> frames;

  final FlutterFrame? selectedFrame;

  bool get isEmpty => perfettoTraceBinary == null;

  Map<String, dynamic> toJson() => {
        traceBinaryKey: perfettoTraceBinary,
        flutterFramesKey: frames.map((frame) => frame.json).toList(),
        selectedFrameIdKey: selectedFrame?.id,
        displayRefreshRateKey: displayRefreshRate,
        rasterStatsKey: rasterStats?.json,
        rebuildCountModelKey: rebuildCountModel?.toJson(),
      };
}

extension type _PerformanceDataJson(Map<String, Object?> json) {
  Uint8List? get traceBinary {
    final value =
        (json[OfflinePerformanceData.traceBinaryKey] as List?)?.cast<int>();
    return value == null ? null : Uint8List.fromList(value);
  }

  RasterStats? get rasterStats {
    final raw = (json[OfflinePerformanceData.rasterStatsKey] as Map? ?? {})
        .cast<String, Object>();
    return raw.isNotEmpty ? RasterStats.parse(raw) : null;
  }

  int? get selectedFrameId =>
      json[OfflinePerformanceData.selectedFrameIdKey] as int?;

  List<FlutterFrame> get frames =>
      (json[OfflinePerformanceData.flutterFramesKey] as List? ?? [])
          .cast<Map>()
          .map((f) => f.cast<String, dynamic>())
          .map((f) => FlutterFrame.parse(f))
          .toList();

  double get displayRefreshRate =>
      (json[OfflinePerformanceData.displayRefreshRateKey] as num?)
          ?.toDouble() ??
      defaultRefreshRate;

  RebuildCountModel? get rebuildCountModel {
    final raw =
        (json[OfflinePerformanceData.rebuildCountModelKey] as Map? ?? {})
            .cast<String, dynamic>();
    return raw.isNotEmpty ? RebuildCountModel.parse(raw) : null;
  }
}

class FlutterTimelineEvent extends TreeNode<FlutterTimelineEvent> {
  FlutterTimelineEvent(PerfettoTrackEvent firstTrackEvent)
      : trackEvents = [firstTrackEvent],
        type = firstTrackEvent.timelineEventType {
    time.start = Duration(microseconds: firstTrackEvent.timestampMicros);
  }

  static const rasterEventName = 'Rasterizer::DoDraw';
  static const uiEventName = 'Animator::BeginFrame';

  /// Perfetto track events associated with this [FlutterTimelineEvent].
  final List<PerfettoTrackEvent> trackEvents;

  TimelineEventType? type;

  TimeRange time = TimeRange();

  String? get name => trackEvents.first.name;

  int? get flutterFrameNumber => trackEvents.first.flutterFrameNumber;

  bool get isUiEvent => type == TimelineEventType.ui;
  bool get isRasterEvent => type == TimelineEventType.raster;
  bool get isShaderEvent =>
      trackEvents.first.isShaderEvent || trackEvents.last.isShaderEvent;

  bool get isWellFormed => time.start != null && time.end != null;

  void addEndTrackEvent(PerfettoTrackEvent event) {
    time.end = Duration(microseconds: event.timestampMicros);
    trackEvents.add(event);
  }

  @override
  FlutterTimelineEvent shallowCopy() {
    final copy = FlutterTimelineEvent(trackEvents.first);
    for (int i = 1; i < trackEvents.length; i++) {
      copy.trackEvents.add(trackEvents[i]);
    }
    copy
      ..type = type
      ..time = (TimeRange()
        ..start = time.start
        ..end = time.end);
    return copy;
  }

  @visibleForTesting
  FlutterTimelineEvent deepCopy() {
    final copy = shallowCopy();
    copy.parent = parent;
    for (FlutterTimelineEvent child in children) {
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
    for (FlutterTimelineEvent child in children) {
      child.writeTrackEventsToBuffer(buf);
    }
    if (end != null) {
      buf.writeln(end.toString());
    }
  }

  void format(StringBuffer buf, String indent) {
    buf.writeln('$indent$name $time');
    for (FlutterTimelineEvent child in children) {
      child.format(buf, '  $indent');
    }
  }
}

enum TimelineEventType {
  ui,
  raster,
  other,
}
