// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:test/test.dart';

void main() {
  test('$HeapSample serializes', () {
    final sample = HeapSample(
      1,
      2,
      3,
      4,
      5,
      true,
      AdbMemoryInfo.empty(),
      EventSample.empty(),
      RasterCache.empty(),
    );

    final json = sample.toJson();
    expect(json.keys.toSet(), equals(Json.values.map((e) => e.name).toSet()));
    final fromJson = HeapSample.fromJson(json);

    expect(sample.timestamp, equals(fromJson.timestamp));
    expect(sample.rss, equals(fromJson.rss));
    expect(sample.capacity, equals(fromJson.capacity));
    expect(sample.used, equals(fromJson.used));
    expect(sample.external, equals(fromJson.external));
    expect(sample.isGC, equals(fromJson.isGC));
    expect(sample.adbMemoryInfo, equals(fromJson.adbMemoryInfo));
    expect(sample.memoryEventInfo, equals(fromJson.memoryEventInfo));
    expect(sample.rasterCache, equals(fromJson.rasterCache));
  });
}
