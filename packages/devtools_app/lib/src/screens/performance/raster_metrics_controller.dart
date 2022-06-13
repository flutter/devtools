// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config_specific/logger/logger.dart' as logger;
import '../../primitives/utils.dart';
import '../../shared/globals.dart';

class RasterMetricsController {
  static const _snapshotsJsonKey = 'snapshots';

  static const _snapshotJsonKey = 'snapshot';

  static const _layerIdKey = 'layer_unique_id';

  static const _durationKey = 'duration_micros';

  ValueListenable<List<LayerSnapshot>> get layerSnapshots => _layerSnapshots;

  final _layerSnapshots = ValueNotifier<List<LayerSnapshot>>([]);

  Size? originalFrameSize;

  ValueListenable<LayerSnapshot?> get selectedSnapshot => _selectedSnapshot;

  final _selectedSnapshot = ValueNotifier<LayerSnapshot?>(null);

  ValueListenable<bool> get loadingSnapshot => _loadingSnapshot;

  final _loadingSnapshot = ValueNotifier<bool>(false);

  Duration _sumRasterTime = Duration.zero;

  void selectSnapshot(LayerSnapshot? snapshot) {
    _selectedSnapshot.value = snapshot;
  }

  Future<void> collectRasterStats() async {
    clear();
    _loadingSnapshot.value = true;
    try {
      final response = await serviceManager.renderFrameWithRasterStats;
      final json = response?.json ?? <String, Object?>{};
      await initDataFromJson(json);
    } catch (e) {
      logger.log('Error collecting raster stats: $e');
      clear();
    } finally {
      _loadingSnapshot.value = false;
    }
  }

  void clear() {
    _layerSnapshots.value = <LayerSnapshot>[];
    originalFrameSize = null;
    _selectedSnapshot.value = null;
    _sumRasterTime = Duration.zero;
  }

  @visibleForTesting
  Future<void> initDataFromJson(Map<String, Object?> json) async {
    originalFrameSize = Size(
      (json['frame_width'] as int).toDouble(),
      (json['frame_height'] as int).toDouble(),
    );

    final snapshotsFromJson =
        (json[_snapshotsJsonKey] as List).cast<Map<String, dynamic>>();
    final snapshots = <LayerSnapshot>[];
    for (final snapshot in snapshotsFromJson) {
      final id = snapshot[_layerIdKey];
      final dur = Duration(microseconds: snapshot[_durationKey] as int);
      final imageBytes = Uint8List.fromList(
        (snapshot[_snapshotJsonKey] as List<dynamic>).cast<int>(),
      );
      final size = Size(
        (snapshot['width'] as int).toDouble(),
        (snapshot['height'] as int).toDouble(),
      );
      final offset = Offset(
        (snapshot['left'] as int).toDouble(),
        (snapshot['top'] as int).toDouble(),
      );
      final image = await imageFromBytes(imageBytes);
      final layerSnapshot = LayerSnapshot(
        id: id,
        duration: dur,
        size: size,
        offset: offset,
        image: image,
        bytes: imageBytes,
      );
      snapshots.add(layerSnapshot);
      _sumRasterTime += dur;
    }

    for (final snapshot in snapshots) {
      snapshot.totalRenderingDuration = _sumRasterTime;
    }

    // Sort by percent rendering time in descending order.
    snapshots.sort(
      (a, b) => b.percentRenderingTimeAsDouble
          .compareTo(a.percentRenderingTimeAsDouble),
    );

    _layerSnapshots.value = snapshots;
    _selectedSnapshot.value = snapshots.safeFirst;
  }

  Future<ui.Image> imageFromBytes(Uint8List bytes) async {
    return await decodeImageFromList(bytes);
  }
}

class LayerSnapshot {
  LayerSnapshot({
    required this.id,
    required this.duration,
    required this.size,
    required this.offset,
    required this.image,
    required this.bytes,
  });

  final int id;

  final Duration duration;

  final Size size;

  final Offset offset;

  final ui.Image image;

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
      percent2(percentRenderingTimeAsDouble);

  String get displayName => 'Layer $id';
}
