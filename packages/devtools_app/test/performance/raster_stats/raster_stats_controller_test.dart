// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/performance/panes/raster_stats/raster_stats_model.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../../test_infra/test_data/performance_raster_stats.dart';

void main() {
  group('$RasterStatsController', () {
    late RasterStatsController controller;
    late MockServiceConnectionManager mockServiceConnection;

    setUp(() {
      mockServiceConnection = createMockServiceConnectionWithDefaults();
      when(mockServiceConnection.renderFrameWithRasterStats).thenAnswer(
        (_) => Future.value(Response.parse(rasterStatsFromServiceJson)),
      );
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(ServiceConnectionManager, mockServiceConnection);
      setGlobal(IdeTheme, IdeTheme());

      controller =
          RasterStatsController(createMockPerformanceControllerWithDefaults());
    });

    test('calling collectRasterStats sets data', () async {
      var rasterStats = controller.rasterStats.value;
      expect(rasterStats, isNull);

      await controller.collectRasterStats();

      rasterStats = controller.rasterStats.value;
      expect(rasterStats, isNotNull);
      expect(rasterStats!.layerSnapshots.length, equals(2));
      expect(rasterStats.selectedSnapshot, isNotNull);
      expect(rasterStats.originalFrameSize, isNotNull);
      expect(rasterStats.totalRasterTime, isNot(equals(Duration.zero)));
    });

    test(
      'calling collectRasterStats sets null data for bad service response',
      () async {
        var rasterStats = controller.rasterStats.value;
        expect(rasterStats, isNull);

        when(mockServiceConnection.renderFrameWithRasterStats)
            .thenAnswer((_) => throw Exception('something went wrong'));
        await controller.collectRasterStats();

        rasterStats = controller.rasterStats.value;
        expect(rasterStats, isNull);
      },
    );

    test('calling clear nulls out raster stats', () async {
      await controller.collectRasterStats();
      var rasterStats = controller.rasterStats.value;
      expect(rasterStats, isNotNull);
      expect(rasterStats!.layerSnapshots.length, equals(2));
      expect(rasterStats.selectedSnapshot, isNotNull);
      expect(rasterStats.originalFrameSize, isNotNull);
      expect(rasterStats.totalRasterTime, isNot(equals(Duration.zero)));

      controller.clearData();

      rasterStats = controller.rasterStats.value;
      expect(rasterStats, isNull);
    });

    test('setOfflineData', () async {
      final rasterStats = RasterStats.parse(rasterStatsFromServiceJson);

      // Ensure we are starting in a null state.
      expect(controller.rasterStats.value, isNull);

      final offlineData = PerformanceData(rasterStats: rasterStats);
      await controller.setOfflineData(offlineData);

      expect(controller.rasterStats.value, isNotNull);
      expect(controller.rasterStats.value!.layerSnapshots.length, equals(2));
    });
  });
}
