// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:async';

import 'package:devtools_app/src/screens/memory/framework/memory_controller.dart';
import 'package:devtools_app/src/screens/memory/panes/chart/controller/memory_tracker.dart';
import 'package:devtools_app/src/screens/memory/shared/primitives/memory_timeline.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_infra/flutter_test_driver.dart' show FlutterRunConfiguration;
import '../../test_infra/flutter_test_environment.dart';

late MemoryController memoryController;

// Track number of onMemory events received.
int memoryTrackersReceived = 0;

int previousTimestamp = 0;

bool firstSample = true;

void main() {
  // TODO(https://github.com/flutter/devtools/issues/2053): rewrite.
  // ignore: dead_code
  if (false) {
    final FlutterTestEnvironment env = FlutterTestEnvironment(
      const FlutterRunConfiguration(withDebugger: true),
    );

    env.afterNewSetup = () async {
      memoryController = MemoryController();
      memoryController.chart.startTimeline();
    };

    group('MemoryController', () {
      tearDownAll(() {
        unawaited(env.tearDownEnvironment(force: true));
      });

      test('heap info', () async {
        await env.setupEnvironment();

        memoryController.chart.onMemory.listen((MemoryTracker? memoryTracker) {
          if (!serviceConnection.serviceManager.hasConnection) {
            // VM Service connection has stopped - unexpected.
            fail('VM Service connection stopped unexpectedly.');
          } else {
            validateHeapInfo(memoryController.chart.memoryTimeline);
          }
        });

        await collectSamples(); // Collect some data.

        expect(memoryTrackersReceived, equals(defaultSampleSize));

        await env.tearDownEnvironment();
      });
    });
  }
}

void validateHeapInfo(MemoryTimeline timeline) {
  for (final HeapSample sample in timeline.data) {
    expect(sample.timestamp, greaterThan(0));
    expect(sample.timestamp, greaterThan(previousTimestamp));

    expect(sample.used, greaterThan(0));
    expect(sample.used, lessThan(sample.capacity));

    expect(sample.external, greaterThan(0));
    expect(sample.external, lessThan(sample.capacity));

    // TODO(terry): Bug - VM's first HeapSample returns a null for the rss value.
    //              Subsequent samples the rss values are valid integers.  This is
    //              a VM regression https://github.com/dart-lang/sdk/issues/40766.
    //              When fixed, remove below test rss != null and firstSample global.
    if (firstSample) {
      expect(sample.rss, greaterThan(0));
      expect(sample.rss, greaterThan(sample.capacity));
      firstSample = false;
    }

    expect(sample.capacity, greaterThan(0));
    expect(sample.capacity, greaterThan(sample.used + sample.external));

    previousTimestamp = sample.timestamp;
  }

  timeline.data.clear();

  memoryTrackersReceived++;
}

const int defaultSampleSize = 5;

Future<void> collectSamples([int sampleCount = defaultSampleSize]) async {
  // Keep memory profiler running for n samples of heap info from the VM.
  for (var trackers = 0; trackers < sampleCount; trackers++) {
    await memoryController.chart.onMemory.first;
  }
}
