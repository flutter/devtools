// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:devtools_app/src/screens/memory/memory_heap_tree_view.dart';
import 'package:devtools_app/src/screens/memory/memory_screen.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/diff_pane.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../scenes/memory/connected.dart';

void main() {
  test('Diff tab is off yet.', () {
    expect(shouldShowDiffPane, false);
  });

  group('Diff pane', () {
    late MemoryConnectedScene scene;

    Future<void> pumpDiffTab(WidgetTester tester) async {
      await tester.pumpWidget(scene.build());
      // Delay to ensure the memory profiler has collected data.
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byType(MemoryBody), findsOneWidget);
      await tester.tap(
        find.byKey(HeapTreeViewState.diffTabKey),
      );
      await tester.pumpAndSettle();
    }

    // Set a wide enough screen width that we do not run into overflow.
    const windowSize = Size(2225.0, 1000.0);

    setUp(() async {
      scene = MemoryConnectedScene();
      await scene.setUp();
    });

    tearDown(() async {
      scene.tearDown();
    });

    testWidgetsWithWindowSize('records snapshots', windowSize,
        (WidgetTester tester) async {
      await pumpDiffTab(tester);
      await tester.tap(find.byIcon(Icons.fiber_manual_record));
      await tester.pumpAndSettle();
    });
  });
}
