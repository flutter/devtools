// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../../../shared/globals.dart';
import '../../performance_controller.dart';
import '../../performance_model.dart';
import '../flutter_frames/flutter_frame_model.dart';
import 'raster_stats_model.dart';

final _log = Logger('raster_stats_controller');

class RasterStatsController extends PerformanceFeatureController {
  RasterStatsController(super.performanceController);

  /// The active raster stats for the view.
  ValueListenable<RasterStats?> get rasterStats => _rasterStats;
  final _rasterStats = ValueNotifier<RasterStats?>(null);

  ValueListenable<bool> get loadingSnapshot => _loadingSnapshot;
  final _loadingSnapshot = ValueNotifier<bool>(false);

  final selectedSnapshot = ValueNotifier<LayerSnapshot?>(null);

  void selectSnapshot(LayerSnapshot? snapshot) {
    assert(_rasterStats.value != null);
    _rasterStats.value!.selectedSnapshot = snapshot;
    selectedSnapshot.value = snapshot;
  }

  Future<void> collectRasterStats() async {
    clearData();
    _loadingSnapshot.value = true;
    try {
      final response = await serviceConnection.renderFrameWithRasterStats;
      final json = response?.json ?? <String, Object?>{};
      final rasterStats = RasterStats.parse(json);
      setData(rasterStats);
    } catch (e, st) {
      _log.shout('Error collecting raster stats: $e', e, st);
      clearData();
    } finally {
      _loadingSnapshot.value = false;
    }
  }

  void setData(RasterStats? stats) {
    _rasterStats.value = stats;
    selectedSnapshot.value = stats?.selectedSnapshot;
    performanceController.data!.rasterStats = stats;
  }

  @override
  void handleSelectedFrame(FlutterFrame frame) {
    // TODO(kenz): show raster stats for the selected frame, if available.
  }

  @override
  Future<void> setOfflineData(PerformanceData offlineData) async {
    final offlineRasterStats = offlineData.rasterStats;
    if (offlineRasterStats != null) {
      setData(offlineRasterStats);
    }
  }

  @override
  void clearData() {
    setData(null);
  }

  @override
  Future<void> init() {
    return Future.value();
  }

  @override
  void onBecomingActive() {}
}
