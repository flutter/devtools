// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:devtools_app/src/screens/memory/panes/leaks/diagnostics/formatter.dart';
import 'package:devtools_app/src/screens/memory/panes/leaks/diagnostics/leak_analyzer.dart';
import 'package:devtools_app/src/screens/memory/panes/leaks/diagnostics/model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker/devtools_integration.dart';

import '../../../test_infra/test_data/memory/leaks/leaks_data.dart';

void main() {
  for (var t in goldenLeakTests) {
    group(t.name, () {
      late NotGCedAnalyzerTask task;

      setUp(() async {
        task = await t.task();
      });

      // This test does not verify results, because the code is not stable yet.
      // We need the test to make sure (1) the code does not fail and (2)
      // to see the changes in the output file in code reviews.
      test('has leaks.', () async {
        final result = analyseNotGCed(task);

        final yaml = analyzedLeaksToYaml(
          gcedLate: [],
          notDisposed: [],
          notGCed: result,
        );

        await File(t.pathForLeakDetails).writeAsString(yaml);
      });
    });
  }

  test('Culprits are found as expected.', () {
    final culprit1 = _createReport(1, '/1/2/');
    final culprit2 = _createReport(2, '/1/7/');

    final notGCed = [
      culprit1,
      _createReport(11, '/1/2/3/4/5/'),
      _createReport(12, '/1/2/3/'),
      culprit2,
      _createReport(21, '/1/7/3/4/5/'),
      _createReport(22, '/1/7/3/'),
    ];

    final culprits = findCulprits(notGCed);

    expect(culprits, hasLength(2));
    expect(culprits.keys, contains(culprit1));
    expect(culprits[culprit1], hasLength(2));
    expect(culprits.keys, contains(culprit2));
    expect(culprits[culprit2], hasLength(2));
  });
}

LeakReport _createReport(int code, String path) => LeakReport(
      type: '',
      context: const <String, dynamic>{},
      code: 0,
      trackedClass: 'trackedClass',
    )..retainingPath = path;
