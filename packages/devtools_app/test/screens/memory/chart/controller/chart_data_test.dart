// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/screens/memory/panes/chart/controller/chart_data.dart';
import 'package:devtools_app/src/screens/memory/shared/primitives/memory_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('$ChartData serializes and deserializes correctly', () {
    var item = ChartData(
      isDeviceAndroid: true,
      timeline: MemoryTimeline(),
      isLegendVisible: true,
    );
    var json = item.toJson();
    expect(json.keys.toSet(), equals(Json.values.map((e) => e.name).toSet()));

    var fromJson = ChartData.fromJson(json);
    expect(fromJson.isDeviceAndroid, item.isDeviceAndroid);
    expect(fromJson.timeline, item.timeline);
    expect(fromJson.displayInterval.name, item.displayInterval.name);
    expect(fromJson.isLegendVisible.value, item.isLegendVisible.value);

    item = ChartData();
    json = item.toJson();
    expect(json.keys.toSet(), equals(Json.values.map((e) => e.name).toSet()));

    fromJson = ChartData.fromJson(item.toJson());
    expect(fromJson.isDeviceAndroid, false);
    expect(fromJson.timeline, item.timeline);
    expect(fromJson.displayInterval.name, item.displayInterval.name);
    expect(fromJson.isLegendVisible.value, item.isLegendVisible.value);
  });
}
