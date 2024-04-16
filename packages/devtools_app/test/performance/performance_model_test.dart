// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_test/test_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/test_data/performance/sample_performance_data.dart';

void main() {
  group('$OfflinePerformanceData', () {
    test('create empty data object', () {
      final offlineData = OfflinePerformanceData();
      expect(offlineData.perfettoTraceBinary, isNull);
      expect(offlineData.frames, isEmpty);
      expect(offlineData.selectedFrame, isNull);
      expect(offlineData.rasterStats, isNull);
      expect(offlineData.rebuildCountModel, isNull);
      expect(offlineData.displayRefreshRate, 60.0);
    });

    test('init from parse', () {
      OfflinePerformanceData offlineData = OfflinePerformanceData.fromJson({});
      expect(offlineData.frames, isEmpty);
      expect(offlineData.selectedFrame, isNull);
      expect(offlineData.selectedFrame, isNull);
      expect(offlineData.displayRefreshRate, equals(60.0));
      expect(offlineData.rasterStats, isNull);

      offlineData = OfflinePerformanceData.fromJson(rawPerformanceData);
      expect(offlineData.perfettoTraceBinary, isNotNull);
      expect(offlineData.frames.length, 3);
      expect(offlineData.selectedFrame, isNotNull);
      expect(offlineData.selectedFrame!.id, equals(2));
      expect(offlineData.displayRefreshRate, equals(60));
      expect(
        offlineData.rasterStats!.json,
        equals(rasterStatsFromDevToolsJson),
      );
      expect(offlineData.rebuildCountModel, isNull);
    });

    test('to json', () {
      OfflinePerformanceData offlineData = OfflinePerformanceData.fromJson({});
      expect(
        offlineData.toJson(),
        equals({
          OfflinePerformanceData.traceBinaryKey: null,
          OfflinePerformanceData.flutterFramesKey: <Object?>[],
          OfflinePerformanceData.selectedFrameIdKey: null,
          OfflinePerformanceData.displayRefreshRateKey: 60,
          OfflinePerformanceData.rasterStatsKey: null,
          OfflinePerformanceData.rebuildCountModelKey: null,
        }),
      );

      offlineData = OfflinePerformanceData.fromJson(rawPerformanceData);
      expect(offlineData.toJson(), rawPerformanceData);
    });
  });

  group('$FlutterTimelineEvent', () {
    test('isUiEvent', () {
      depthFirstTraversal(
        FlutterFrame6.uiEvent,
        action: (node) {
          expect(
            node.isUiEvent,
            true,
            reason: 'Expected ${node.name} event to have type '
                '${TimelineEventType.ui}.',
          );
        },
      );
    });

    test('isRasterFrameIdentifier', () {
      depthFirstTraversal(
        FlutterFrame6.rasterEvent,
        action: (node) {
          expect(
            node.isRasterEvent,
            true,
            reason: 'Expected ${node.name} event to have type '
                '${TimelineEventType.raster}.',
          );
        },
      );
    });
  });
}
