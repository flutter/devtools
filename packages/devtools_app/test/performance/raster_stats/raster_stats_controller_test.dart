// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/performance/panes/raster_stats/raster_stats_controller.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../../test_data/performance_raster_stats.dart';

void main() {
  group('$RasterStatsController', () {
    late RasterStatsController controller;

    setUp(() async {
      final mockServiceManager = MockServiceConnectionManager();
      when(mockServiceManager.renderFrameWithRasterStats).thenAnswer(
        (_) => Future.value(Response.parse(rasterStatsFromService)),
      );
      setGlobal(ServiceConnectionManager, mockServiceManager);
      setGlobal(IdeTheme, IdeTheme());

      controller = RasterStatsController();
      await controller.collectRasterStats();
    });

    test('clear', () async {
      var rasterStats = controller.rasterStats.value;
      expect(rasterStats.layerSnapshots.length, equals(2));
      expect(rasterStats.selectedSnapshot, isNotNull);
      expect(rasterStats.originalFrameSize, isNotNull);
      expect(rasterStats.totalRasterTime, isNot(equals(Duration.zero)));

      controller.clear();

      rasterStats = controller.rasterStats.value;
      expect(rasterStats.layerSnapshots, isEmpty);
      expect(rasterStats.selectedSnapshot, isNull);
      expect(rasterStats.originalFrameSize, isNull);
      expect(rasterStats.totalRasterTime, equals(Duration.zero));
    });
  });
}
