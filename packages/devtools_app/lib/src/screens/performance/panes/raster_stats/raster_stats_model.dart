// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../shared/primitives/utils.dart';

class RasterStats {
  RasterStats._({
    required this.layerSnapshots,
    required this.originalFrameSize,
    required this.totalRasterTime,
    required this.selectedSnapshot,
  });

  factory RasterStats.fromJson(Map<String, Object?> json) {
    Size? originalFrameSize;
    final originalWidth = json[_frameWidthKey] as num?;
    final originalHeight = json[_frameHeightKey] as num?;
    if (originalHeight != null && originalWidth != null) {
      originalFrameSize = Size(
        originalWidth.toDouble(),
        originalHeight.toDouble(),
      );
    }
    int? selectedId;
    LayerSnapshot? selected;
    if (json[_selectedIdKey] != null) {
      selectedId = json[_selectedIdKey] as int?;
    }

    final snapshotsFromJson =
        (json[_snapshotsJsonKey] as List).cast<Map<String, dynamic>>();

    final snapshots = <LayerSnapshot>[];
    var totalRasterTime = Duration.zero;
    for (final snapshotJson in snapshotsFromJson) {
      final layerSnapshot = LayerSnapshot.fromJson(snapshotJson);
      snapshots.add(layerSnapshot);
      totalRasterTime += layerSnapshot.duration;
      if (layerSnapshot.id == selectedId) {
        selected = layerSnapshot;
      }
    }

    for (final snapshot in snapshots) {
      snapshot.totalRenderingDuration = totalRasterTime;
    }

    // Sort by percent rendering time in descending order.
    snapshots.sort(
      (a, b) => b.percentRenderingTimeAsDouble
          .compareTo(a.percentRenderingTimeAsDouble),
    );

    selected ??= snapshots.safeFirst;

    return RasterStats._(
      layerSnapshots: snapshots,
      selectedSnapshot: selected,
      originalFrameSize: originalFrameSize,
      totalRasterTime: totalRasterTime,
    );
  }

  static const _snapshotsJsonKey = 'snapshots';

  static const _selectedIdKey = 'selectedId';

  static const _frameWidthKey = 'frame_width';

  static const _frameHeightKey = 'frame_height';

  final List<LayerSnapshot> layerSnapshots;

  final Size? originalFrameSize;

  final Duration totalRasterTime;

  /// The selected snapshot for this set of raster stats data.
  ///
  /// This field is mutable, and is managed by the [RasterStatsController]. It
  /// is included in [RasterStats] so that it can be encoded in and decoded from
  /// json.
  LayerSnapshot? selectedSnapshot;

  Map<String, dynamic> get json => {
        _frameWidthKey: originalFrameSize?.width.toDouble(),
        _frameHeightKey: originalFrameSize?.height.toDouble(),
        _snapshotsJsonKey: layerSnapshots
            .map((snapshot) => snapshot.json)
            .toList(growable: false),
        _selectedIdKey: selectedSnapshot?.id,
      };
}

class LayerSnapshot {
  LayerSnapshot({
    required this.id,
    required this.duration,
    required this.size,
    required this.offset,
    required this.bytes,
  });

  factory LayerSnapshot.fromJson(Map<String, Object?> json) {
    final id = json[_layerIdKey] as int;
    final dur = Duration(microseconds: json[_durationKey] as int);
    final size = Size(
      (json[_widthKey] as num).toDouble(),
      (json[_heightKey] as num).toDouble(),
    );
    final offset = Offset(
      (json[_leftKey] as num).toDouble(),
      (json[_topKey] as num).toDouble(),
    );
    final imageBytes = Uint8List.fromList(
      (json[_snapshotJsonKey] as List<Object?>).cast<int>(),
    );
    return LayerSnapshot(
      id: id,
      duration: dur,
      size: size,
      offset: offset,
      bytes: imageBytes,
    );
  }

  static const _layerIdKey = 'layer_unique_id';
  static const _durationKey = 'duration_micros';
  static const _snapshotJsonKey = 'snapshot';
  static const _widthKey = 'width';
  static const _heightKey = 'height';
  static const _leftKey = 'left';
  static const _topKey = 'top';

  final int id;

  final Duration duration;

  final Size size;

  final Offset offset;

  final Uint8List bytes;

  /// The total rendering time for the set of snapshots that this
  /// [LayerSnapshot] is a part of.
  ///
  /// This will be set after this [LayerSnapshot] is created, once all the
  /// [LayerSnapshot]s in a set have been processed.
  Duration? totalRenderingDuration;

  double get percentRenderingTimeAsDouble =>
      duration.inMicroseconds / totalRenderingDuration!.inMicroseconds;

  String get percentRenderingTimeDisplay =>
      percent(percentRenderingTimeAsDouble);

  String get displayName => 'Layer $id';

  Map<String, Object?> get json => {
        _layerIdKey: id,
        _durationKey: duration.inMicroseconds,
        _widthKey: size.width,
        _heightKey: size.height,
        _leftKey: offset.dx,
        _topKey: offset.dy,
        _snapshotJsonKey: bytes,
      };
}
