// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/screens/memory/memory_controller.dart';
import 'package:devtools_app/src/screens/memory/memory_protocol.dart';
import 'package:devtools_app/src/screens/memory/memory_timeline.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/flutter_test_driver.dart' show FlutterRunConfiguration;
import '../test_infra/flutter_test_environment.dart';

late MemoryController memoryController;

// Track number of onMemory events received.
int memoryTrackersReceived = 0;

int previousTimestamp = 0;

bool firstSample = true;

void main() async {
  // TODO(https://github.com/flutter/devtools/issues/2053): rewrite.
  // ignore: dead_code
  if (false) {
    final FlutterTestEnvironment env = FlutterTestEnvironment(
      const FlutterRunConfiguration(withDebugger: true),
    );

    env.afterNewSetup = () async {
      memoryController = MemoryController();
      await memoryController.startTimeline();
    };

    group('MemoryController', () {
      tearDownAll(() {
        env.tearDownEnvironment(force: true);
      });

      test('heap info', () async {
        await env.setupEnvironment();

        memoryController.onMemory.listen((MemoryTracker? memoryTracker) {
          if (!serviceManager.hasConnection) {
            // VM Service connection has stopped - unexpected.
            fail('VM Service connection stoped unexpectantly.');
          } else {
            validateHeapInfo(memoryController.memoryTimeline);
          }
        });

        await collectSamples(); // Collect some data.

        expect(memoryTrackersReceived, equals(defaultSampleSize));

        await env.tearDownEnvironment();
      });

      test('allocations', () async {
        await env.setupEnvironment();

        final List<ClassHeapDetailStats> classStats =
            await memoryController.getAllocationProfile();

        final Iterator<ClassHeapDetailStats> iterator = classStats.iterator;
        while (iterator.moveNext()) {
          final ClassHeapDetailStats classStat = iterator.current;

          if (classStat.classRef.name == 'MyApp') {
            checkHeapStat(
              classStat,
              'MyApp',
              instanceCount: 1,
              accumulatorCount: 2,
            );
          } else if (classStat.classRef.name == 'ThemeData') {
            checkHeapStat(
              classStat,
              'ThemeData',
              instanceCount: 2,
              accumulatorCount: 4,
            );
          } else if (classStat.classRef.name == 'AppBar') {
            checkHeapStat(
              classStat,
              'AppBar',
              instanceCount: 1,
              accumulatorCount: 2,
            );
          } else if (classStat.classRef.name == 'Center') {
            checkHeapStat(
              classStat,
              'Center',
              instanceCount: 1,
              accumulatorCount: 2,
            );
          }
        }

        await env.tearDownEnvironment();
      });

      test('reset', () async {
        await env.setupEnvironment();

        final List<ClassHeapDetailStats> classStats =
            await memoryController.getAllocationProfile(reset: true);
        final Iterator<ClassHeapDetailStats> iterator = classStats.iterator;
        while (iterator.moveNext()) {
          final ClassHeapDetailStats classStat = iterator.current;

          if (classStat.classRef.name == 'MyApp') {
            checkHeapStat(
              classStat,
              'MyApp',
              instanceCount: 1,
              accumulatorCount: 0,
            );
          } else if (classStat.classRef.name == 'ThemeData') {
            checkHeapStat(
              classStat,
              'ThemeData',
              instanceCount: 2,
              accumulatorCount: 0,
            );
          } else if (classStat.classRef.name == 'AppBar') {
            checkHeapStat(
              classStat,
              'AppBar',
              instanceCount: 1,
              accumulatorCount: 0,
            );
          } else if (classStat.classRef.name == 'Center') {
            checkHeapStat(
              classStat,
              'Center',
              instanceCount: 1,
              accumulatorCount: 0,
            );
          }
        }

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
    await memoryController.onMemory.first;
  }
}

void checkHeapStat(
  ClassHeapDetailStats classStat,
  String className, {
  int? instanceCount,
  int? accumulatorCount,
}) {
  expect(classStat.classRef.name, equals(className));
  expect(classStat.instancesCurrent, equals(instanceCount));
  // TODO(terry): investigate this failure.
  //  expect(classStat.instancesAccumulated, equals(accumulatorCount));
}
