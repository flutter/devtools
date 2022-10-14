// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/primitives/feature_flags.dart';
import 'package:devtools_app/src/screens/memory/memory_heap_tree_view.dart';
import 'package:devtools_app/src/screens/memory/memory_screen.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/diff_pane.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../matchers/matchers.dart';
import '../../scenes/memory/default.dart';

void main() {
  test('Diff tab is off yet.', () {
    expect(FeatureFlags.memoryDiffing, false);
  });

  group('Diff pane', () {
    late MemoryDefaultScene scene;
    final finder = find.byType(DiffPane);

    Future<void> pumpDiffTab(WidgetTester tester) async {
      await tester.pumpWidget(scene.build());
      // Delay to ensure the memory profiler has collected data.
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byType(MemoryBody), findsOneWidget);
      await tester.tap(
        find.byKey(MemoryScreenKeys.diffTab),
      );
      await tester.pumpAndSettle();
    }

    // Set a wide enough screen width that we do not run into overflow.
    const windowSize = Size(2225.0, 1000.0);

    setUp(() async {
      scene = MemoryDefaultScene();
      await scene.setUp();
    });

    tearDown(() async {
      scene.tearDown();
    });

    testWidgetsWithWindowSize('records and deletes snapshots', windowSize,
        (WidgetTester tester) async {
      final snapshots = scene.controller.diffPaneController.core.snapshots;
      // Check the list contains only documentation item.
      expect(snapshots.value.length, equals(1));
      await pumpDiffTab(tester);

      // Check initial golden.
      await expectLater(
        finder,
        matchesDevToolsGolden('../../goldens/memory_diff_empty1.png'),
      );

      // Record three snapshots.
      for (var i in Iterable.generate(3)) {
        await tester.tap(find.byIcon(Icons.fiber_manual_record));
        await tester.pumpAndSettle();
        expect(find.text('selected-isolate-${i + 1}'), findsOneWidget);
      }
      await expectLater(
        finder,
        matchesDevToolsGolden('../../goldens/memory_diff_three_snapshots1.png'),
      );
      expect(snapshots.value.length, equals(1 + 3));

      // Select a class.
      await tester.tap(find.byTooltip('my_lib/root'));
      await tester.pumpAndSettle();
      await expectLater(
        finder,
        matchesDevToolsGolden('../../goldens/memory_diff_selected_class.png'),
      );

      // Delete a snapshot.
      await tester.tap(find.byTooltip('Delete snapshot'));
      await tester.pumpAndSettle();
      expect(snapshots.value.length, equals(1 + 3 - 1));

      // Record snapshot
      await tester.tap(find.byIcon(Icons.fiber_manual_record));
      await tester.pumpAndSettle();
      await expectLater(
        finder,
        matchesDevToolsGolden('../../goldens/memory_diff_three_snapshots2.png'),
      );
      expect(snapshots.value.length, equals(1 + 3 - 1 + 1));

      // Clear all
      await tester.tap(find.byTooltip('Clear all snapshots'));
      await tester.pumpAndSettle();
      await expectLater(
        finder,
        matchesDevToolsGolden('../../goldens/memory_diff_empty2.png'),
      );
      expect(snapshots.value.length, equals(1));
    });
  });
}
