// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/memory/framework/connected/memory_tabs.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/diff_pane.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/widgets/snapshot_list.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_infra/matchers/matchers.dart';
import '../../../test_infra/scenes/memory/default.dart';
import '../../../test_infra/scenes/scene_test_extensions.dart';

Future<void> pumpScene(WidgetTester tester, MemoryDefaultScene scene) async {
  await tester.pumpScene(scene);
  // Delay to ensure the memory profiler has collected data.
  await tester.pumpAndSettle(const Duration(seconds: 1));
  expect(find.byType(MemoryBody), findsOneWidget);
  await tester.tap(
    find.byKey(MemoryScreenKeys.diffTab),
  );
  await tester.pumpAndSettle();
}

Future<void> takeSnapshot(WidgetTester tester, MemoryDefaultScene scene) async {
  final snapshots = scene.controller.diff.core.snapshots;
  final length = snapshots.value.length;
  await tester.tap(find.byIcon(Icons.fiber_manual_record).first);
  await tester.pumpAndSettle();
  expect(snapshots.value.length, equals(length + 1));
}

// Set a wide enough screen width that we do not run into overflow.
const windowSize = Size(2225.0, 1000.0);

void main() {
  late MemoryDefaultScene scene;
  setUp(() {
    scene = MemoryDefaultScene();
  });

  tearDown(() {
    scene.tearDown();
  });

  group('Diff pane', () {
    setUp(() async {
      await scene.setUp(heapProviders: MemoryDefaultSceneHeaps.forDiffTesting);
    });

    testWidgetsWithWindowSize(
      'records and deletes snapshots',
      windowSize,
      (WidgetTester tester) async {
        final snapshots = scene.controller.diff.core.snapshots;
        // Check the list contains only documentation item.
        expect(snapshots.value.length, equals(1));
        await pumpScene(tester, scene);

        // Check initial golden.
        await expectLater(
          find.byType(DiffPane),
          matchesDevToolsGolden(
            '../../../test_infra/goldens/memory_diff_empty1.png',
          ),
        );

        // Record three snapshots.
        for (var i in Iterable<int>.generate(3)) {
          await takeSnapshot(tester, scene);
          expect(find.text('selected-isolate-${i + 1}'), findsOneWidget);
        }

        await expectLater(
          find.byType(DiffPane),
          matchesDevToolsGolden(
            '../../../test_infra/goldens/memory_diff_three_snapshots1.png',
          ),
        );
        expect(snapshots.value.length, equals(1 + 3));

        await expectLater(
          find.byType(DiffPane),
          matchesDevToolsGolden(
            '../../../test_infra/goldens/memory_diff_selected_class.png',
          ),
        );

        // Delete a snapshot.
        await tester.tap(
          find.descendant(
            of: find.byType(SnapshotListTitle),
            matching: find.byType(ContextMenuButton),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(MenuItemButton),
            matching: find.text('Delete'),
          ),
        );
        await tester.pumpAndSettle();
        expect(snapshots.value.length, equals(1 + 3 - 1));

        // Record snapshot
        await takeSnapshot(tester, scene);
        await expectLater(
          find.byType(DiffPane),
          matchesDevToolsGolden(
            '../../../test_infra/goldens/memory_diff_three_snapshots2.png',
          ),
        );
        expect(snapshots.value.length, equals(1 + 3 - 1 + 1));

        // Clear all
        await tester.tap(find.byTooltip('Delete all snapshots'));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(DiffPane),
          matchesDevToolsGolden(
            '../../../test_infra/goldens/memory_diff_empty2.png',
          ),
        );
        expect(snapshots.value.length, equals(1));
      },
    );
  });
}
