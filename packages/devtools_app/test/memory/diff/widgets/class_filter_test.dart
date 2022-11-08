// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/panes/diff/diff_pane.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../matchers/matchers.dart';
import '../../../scenes/memory/diff_snapshot.dart';

void main() {
  late DiffSnapshotScene scene;

  Future<void> pumpSnapshot(WidgetTester tester) async {
    await tester.pumpWidget(scene.build());
    // Delay to ensure the memory profiler has collected data.
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await expectLater(
      find.byType(SnapshotInstanceItemPane),
      matchesDevToolsGolden('../../../goldens/memory_diff_snapshot_scene.png'),
    );
    expect(
      scene.diffController.core.snapshots.value
          .where((element) => element.hasData),
      hasLength(2),
    );
  }

  // Set a wide enough screen width that we do not run into overflow.
  const windowSize = Size(2225.0, 1000.0);

  setUp(() async {
    scene = DiffSnapshotScene();
    await scene.setUp();
  });

  tearDown(() async {
    scene.tearDown();
  });

  testWidgetsWithWindowSize('filters classes', windowSize,
      (WidgetTester tester) async {
    await pumpSnapshot(tester);

    // Check initial golden.
  });
}
