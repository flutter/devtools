// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools/src/memory/memory_controller.dart';
import 'package:devtools/src/memory/memory_protocol.dart';
import 'package:test/test.dart';

import 'support/flutter_test_driver.dart' show FlutterRunConfiguration;
import 'support/flutter_test_environment.dart';

final int currentDateTimeinMs = DateTime.now().millisecondsSinceEpoch;

int previousTimestamp = 0;

void validateHeapInfo(MemoryTracker data) {
  for (final HeapSample sample in data.samples) {
    expect(sample.timestamp > 0, isTrue);
    expect(sample.timestamp > previousTimestamp, isTrue);
    expect(currentDateTimeinMs < sample.timestamp, isTrue);

    expect(sample.used > 0, isTrue);
    expect(sample.used < sample.capacity, isTrue);

    expect(sample.external > 0, isTrue);
    expect(sample.external < sample.capacity, isTrue);

    expect(sample.rss > 0, isTrue);
    expect(sample.rss > sample.capacity, isTrue);

    expect(sample.capacity > 0, isTrue);
    expect(sample.capacity > sample.used + sample.external, isTrue);

    previousTimestamp = sample.timestamp;
  }
  data.samples.clear();
}

void main() {
  group('MemoryController', () {
    final memoryController = MemoryController();

    final env = FlutterTestEnvironment(
      const FlutterRunConfiguration(withDebugger: true),
    );

    env.afterNewSetup = () async {
      await memoryController.startTimeline();

      memoryController.onMemory.listen((MemoryTracker memoryTracker) {
        if (!memoryController.memoryTracker.hasConnection) {
          // VM Service connection has stopped - unexpected.
          expect(true, isFalse);
        } else {
          validateHeapInfo(memoryTracker);
        }
      });
    };
  }, tags: 'useFlutterSdk');
}
