// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/panes/chart/controller/chart_data.dart';
import 'package:devtools_app/src/screens/memory/panes/chart/data/primitives.dart';
import 'package:devtools_app/src/screens/memory/shared/primitives/memory_timeline.dart';
import 'package:devtools_app/src/shared/primitives/simple_items.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    '$ChartData serializes and deserializes correctly, offline',
    () {
      final item = ChartData(
        mode: ControllerCreationMode.offlineData,
        isDeviceAndroid: true,
        timeline: MemoryTimeline(),
        interval: ChartInterval.theDefault,
        isLegendVisible: true,
      );

      final fromJson = ChartData.fromJson(item.toJson());

      expect(fromJson.isDeviceAndroid, item.isDeviceAndroid);
      expect(fromJson.timeline, item.timeline);
      expect(fromJson.displayInterval.name, item.displayInterval.name);
      expect(fromJson.isLegendVisible.value, item.isLegendVisible.value);
    },
  );

  test(
    '$ChartData serializes and deserializes correctly, connected',
    () {
      final item = ChartData(mode: ControllerCreationMode.connected);
      final fromJson = ChartData.fromJson(item.toJson());

      expect(fromJson.isDeviceAndroid, false);
      expect(fromJson.timeline, item.timeline);
      expect(fromJson.displayInterval.name, item.displayInterval.name);
      expect(fromJson.isLegendVisible.value, item.isLegendVisible.value);
    },
  );
}
