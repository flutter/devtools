// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../../../config_specific/logger/logger.dart' as logger;
import '../../../../shared/globals.dart';
import 'raster_stats_model.dart';

class RasterStatsController {
  ValueListenable<RasterStats> get rasterStats => _rasterStats;

  final _rasterStats = ValueNotifier<RasterStats>(RasterStats.empty());

  ValueListenable<bool> get loadingSnapshot => _loadingSnapshot;

  final _loadingSnapshot = ValueNotifier<bool>(false);

  ValueListenable<LayerSnapshot?> get selectedSnapshot => _selectedSnapshot;

  final _selectedSnapshot = ValueNotifier<LayerSnapshot?>(null);

  void selectSnapshot(LayerSnapshot? snapshot) {
    _rasterStats.value.selectedSnapshot = snapshot;
    _selectedSnapshot.value = snapshot;
  }

  Future<void> collectRasterStats() async {
    clear();
    _loadingSnapshot.value = true;
    try {
      final response = await serviceManager.renderFrameWithRasterStats;
      final json = response?.json ?? <String, Object?>{};
      final rasterStats = RasterStats.parse(json);
      setNotifiersForRasterStats(rasterStats);
    } catch (e, st) {
      logger.log('Error collecting raster stats: $e\n\n$st');
      clear();
    } finally {
      _loadingSnapshot.value = false;
    }
  }

  void setNotifiersForRasterStats(RasterStats stats) {
    _rasterStats.value = stats;
    _selectedSnapshot.value = stats.selectedSnapshot;
  }

  void clear() {
    setNotifiersForRasterStats(RasterStats.empty());
  }
}
