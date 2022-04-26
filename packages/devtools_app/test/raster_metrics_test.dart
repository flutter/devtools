// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:devtools_app/src/screens/performance/raster_metrics_controller.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_data/raster_metrics_test_data.dart';

void main() {
  late TestRasterMetricsController controller;

  group('RasterMetricsController', () {
    setUp(() {
      controller = TestRasterMetricsController();
    });

    test('initDataFromJson', () async {
      await controller.initDataFromJson(renderStats);
      final layerSnapshots = controller.layerSnapshots.value;
      expect(layerSnapshots.length, equals(2));
      final first = layerSnapshots[0];
      final second = layerSnapshots[1];
      expect(first.id, equals(12731));
      expect(first.duration.inMicroseconds, equals(389));
      expect(first.totalRenderingDuration!.inMicroseconds, equals(494));
      expect(first.percentRenderingTimeDisplay, equals('78.74%'));
      expect(second.id, equals(12734));
      expect(second.duration.inMicroseconds, equals(105));
      expect(second.totalRenderingDuration!.inMicroseconds, equals(494));
      expect(second.percentRenderingTimeDisplay, equals('21.26%'));

      expect(controller.selectedSnapshot.value, equals(first));
    });

    test('clear', () async {
      await controller.initDataFromJson(renderStats);
      expect(controller.layerSnapshots.value.length, equals(2));
      expect(controller.selectedSnapshot.value, isNotNull);

      controller.clear();

      expect(controller.layerSnapshots.value, isEmpty);
      expect(controller.selectedSnapshot.value, isNull);
    });
  });

  // TODO(kenz): add widget tests for code in raster_metrics.dart once the UI is
  // stable.
}

class TestRasterMetricsController extends RasterMetricsController {
  @override
  Future<ui.Image> imageFromBytes(Uint8List bytes) async {
    return MockImage();
  }
}
