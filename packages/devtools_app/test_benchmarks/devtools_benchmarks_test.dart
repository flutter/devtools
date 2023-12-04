// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Note: this test was modeled after the example test from Flutter Gallery:
// https://github.com/flutter/gallery/blob/master/test_benchmarks/benchmarks_test.dart

import 'dart:convert' show JsonEncoder;
import 'dart:io';

import 'package:test/test.dart';
import 'package:web_benchmarks/server.dart';

import 'test_infra/common.dart';
import 'test_infra/project_root_directory.dart';

final metricList = <String>[
  'preroll_frame',
  'apply_frame',
  'drawFrameDuration',
];

final valueList = <String>[
  'average',
  'outlierAverage',
  'outlierRatio',
  'noise',
];

/// Tests that the DevTools web benchmarks are run and reported correctly.
Future<void> main() async {
  test(
    'Can run a web benchmark',
    () async {
      stdout.writeln('Starting web benchmark tests ...');

      final taskResult = await serveWebBenchmark(
        benchmarkAppDirectory: projectRootDirectory(),
        entryPoint: 'test_benchmarks/test_infra/client.dart',
        useCanvasKit: true,
        treeShakeIcons: false,
        // Pass an empty initial page so that the benchmark server does not
        // attempt to load the default page 'index.html', which will show up as
        // "page not found" in DevTools.
        initialPage: '',
      );

      stdout.writeln('Web benchmark tests finished.');

      expect(taskResult.scores.keys, hasLength(benchmarkList.length));

      for (final benchmarkName in benchmarkList) {
        expect(
          taskResult.scores[benchmarkName],
          hasLength(metricList.length * valueList.length + 1),
        );

        for (final metricName in metricList) {
          for (final valueName in valueList) {
            expect(
              taskResult.scores[benchmarkName]?.where(
                (score) => score.metric == '$metricName.$valueName',
              ),
              hasLength(1),
            );
          }
        }

        expect(
          taskResult.scores[benchmarkName]?.where(
            (score) => score.metric == 'totalUiFrame.average',
          ),
          hasLength(1),
        );
      }

      expect(
        const JsonEncoder.withIndent('  ').convert(taskResult.toJson()),
        isA<String>(),
      );
    },
    timeout: Timeout.none,
  );
}
