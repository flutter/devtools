// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/charts/treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/utils.dart';
import 'support/wrappers.dart';

void main() {
  group('Treemap', () {
    TreemapNode root;

    setUp(() async {
      root = await loadInstructionSizesJson();
    });

    void changeRoot(TreemapNode newRoot) {
      root = newRoot;
    }

    // Pump treemap widget with tree built with test data.
    Future<void> pumpTreemapWidget(WidgetTester tester, Key treemapKey) async {
      await tester.pumpWidget(wrap(LayoutBuilder(
        key: treemapKey,
        builder: (context, constraints) {
          return Treemap.fromRoot(
            rootNode: root,
            levelsVisible: 2,
            isOutermostLevel: true,
            height: constraints.maxHeight,
            onRootChangedCallback: changeRoot,
          );
        },
      )));

      await tester.pumpAndSettle();
    }

    const windowSize = Size(2225.0, 1000.0);

    testWidgetsWithWindowSize('builds treemap with expected data', windowSize,
        (WidgetTester tester) async {
      const treemapKey = Key('Treemap');
      await pumpTreemapWidget(tester, treemapKey);

      expect(find.byKey(treemapKey), findsOneWidget);

      await expectLater(
        find.byKey(treemapKey),
        matchesGoldenFile('goldens/treemap.png'),
      );
      // Await delay for golden comparison.
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgetsWithWindowSize(
        'builds treemap with expected data after zooming in', windowSize,
        (WidgetTester tester) async {
      const treemapKey = Key('Treemap');
      await pumpTreemapWidget(tester, treemapKey);
      
      var text = 'package:flutter/src [1.82 MB]';
      expect(find.text(text), findsOneWidget);
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
      
      await pumpTreemapWidget(tester, treemapKey);
      
      text = 'dart:core [368 KB]';
      expect(find.text(text), findsNothing);

      await expectLater(
        find.byKey(treemapKey),
        matchesGoldenFile('goldens/treemap_zoom.png'),
      );
      // Await delay for golden comparison.
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });
  });
}
