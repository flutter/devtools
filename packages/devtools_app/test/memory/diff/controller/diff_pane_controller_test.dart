// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/framework/memory_tabs.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/controller/diff_pane_controller.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/controller/diff_pane_controller.dart'
    as diff_pane_controller show Json;
import 'package:devtools_app/src/screens/memory/panes/diff/controller/snapshot_item.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_infra/scenes/memory/default.dart';

Future<void> pumpScene(WidgetTester tester, MemoryDefaultScene scene) async {
  await scene.pump(tester);

  await tester.tap(find.byKey(MemoryScreenKeys.diffTab));
  await tester.pumpAndSettle();
}

// Set a wide enough screen width that we do not run into overflow.
const windowSize = Size(2225.0, 1000.0);

void main() {
  late MemoryDefaultScene scene;
  setUp(() async {
    scene = MemoryDefaultScene();
    await scene.setUp();
  });

  tearDown(() {
    scene.tearDown();
  });

  testWidgetsWithWindowSize(
    '$DiffPaneController serializes and deserializes correctly.',
    windowSize,
    (WidgetTester tester) async {
      await pumpScene(tester, scene);
      await scene.goToDiffTab(tester);
      await scene.takeSnapshot(tester);
      await scene.takeSnapshot(tester);

      final controller = scene.controller.diff;

      final snapshots =
          controller.core.snapshots.value.whereType<SnapshotDataItem>();

      expect(snapshots.length, 2);
      snapshots.first.diffWith.value = snapshots.last;

      final json = controller.toJson();
      expect(
        json.keys.toSet(),
        equals(diff_pane_controller.Json.values.map((e) => e.key).toSet()),
      );
      final fromJson = DiffPaneController.fromJson(json);

      final snapshotsFromJson =
          fromJson.core.snapshots.value.whereType<SnapshotDataItem>();

      expect(snapshotsFromJson.length, 2);
      expect(
        snapshotsFromJson.first.diffWith.value == snapshotsFromJson.last,
        true,
      );
      expect(snapshotsFromJson.last.diffWith.value, null);

      expect(snapshotsFromJson.first.name, snapshots.first.name);
      expect(snapshotsFromJson.last.name, snapshots.last.name);
    },
  );
}
