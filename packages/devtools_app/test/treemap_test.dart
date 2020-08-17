// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:devtools_app/src/charts/treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

import 'support/code_size_test_data/new_v8.dart';
import 'support/code_size_test_data/sizes.dart';
import 'support/code_size_test_data/small_sizes.dart';
import 'support/utils.dart';
import 'support/wrappers.dart';

void main() {
  group(
    'Treemap from small instruction sizes',
    () {
      TreemapNode root;

      setUp(() async {
        root = await loadSnapshotJsonAsTree(smallInstructionSizes);
      });

      void changeRoot(TreemapNode newRoot) {
        root = newRoot;
      }

      // Pump treemap widget with tree built with test data.
      Future<void> pumpTreemapWidget(
        WidgetTester tester,
        Key treemapKey,
      ) async {
        await tester.pumpWidget(wrap(LayoutBuilder(
          key: treemapKey,
          builder: (context, constraints) {
            return Treemap.fromRoot(
              rootNode: root,
              levelsVisible: 2,
              isOutermostLevel: true,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              onRootChangedCallback: changeRoot,
            );
          },
        )));

        await tester.pumpAndSettle();
      }

      const windowSize = Size(2225.0, 1000.0);

      testWidgetsWithWindowSize(
        'zooms in down to a node without children',
        windowSize,
        (WidgetTester tester) async {
          const treemapKey = Key('Treemap');
          await pumpTreemapWidget(tester, treemapKey);

          String text = 'dart:_internal [0.3 KB]';
          expect(find.text(text), findsOneWidget);
          await tester.tap(find.text(text));
          await tester.pumpAndSettle();

          await pumpTreemapWidget(tester, treemapKey);

          text = 'CastIterable [0.2 KB]';
          expect(find.text(text), findsOneWidget);
          await tester.tap(find.text(text));
          await tester.pumpAndSettle();

          await pumpTreemapWidget(tester, treemapKey);

          text = 'new CastIterable.\n[0.2 KB]';
          expect(find.text(text), findsOneWidget);
          await tester.tap(find.text(text));
          await tester.pumpAndSettle();

          await pumpTreemapWidget(tester, treemapKey);

          expect(find.text('new CastIterable. [0.2 KB]'), findsOneWidget);
        },
        skip: kIsWeb || !Platform.isMacOS,
      );
    },
  );
  group(
    'Treemap from instruction sizes',
    () {
      TreemapNode root;

      setUp(() async {
        root = await loadSnapshotJsonAsTree(instructionSizes);
      });

      void changeRoot(TreemapNode newRoot) {
        root = newRoot;
      }

      // Pump treemap widget with tree built with test data.
      Future<void> pumpTreemapWidget(
        WidgetTester tester,
        Key treemapKey,
      ) async {
        await tester.pumpWidget(wrap(LayoutBuilder(
          key: treemapKey,
          builder: (context, constraints) {
            return Treemap.fromRoot(
              rootNode: root,
              levelsVisible: 2,
              isOutermostLevel: true,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              onRootChangedCallback: changeRoot,
            );
          },
        )));

        await tester.pumpAndSettle();
      }

      const windowSize = Size(2225.0, 1000.0);

      testWidgetsWithWindowSize(
        'builds treemap with expected data',
        windowSize,
        (WidgetTester tester) async {
          const treemapKey = Key('Treemap');
          await pumpTreemapWidget(tester, treemapKey);

          expect(find.byKey(treemapKey), findsOneWidget);

          await expectLater(
            find.byKey(treemapKey),
            matchesGoldenFile('goldens/treemap_sizes.png'),
          );
          // Await delay for golden comparison.
          await tester.pumpAndSettle(const Duration(seconds: 2));
        },
        skip: kIsWeb || !Platform.isMacOS,
      );
    },
  );

  group(
    'Treemap from v8 snapshots',
    () {
      TreemapNode root;

      setUp(() async {
        root = await loadSnapshotJsonAsTree(newV8);
      });

      void changeRoot(TreemapNode newRoot) {
        root = newRoot;
      }

      // Pump treemap widget with tree built with test data.
      Future<void> pumpTreemapWidget(
          WidgetTester tester, Key treemapKey) async {
        await tester.pumpWidget(wrap(LayoutBuilder(
          key: treemapKey,
          builder: (context, constraints) {
            return Treemap.fromRoot(
              rootNode: root,
              levelsVisible: 2,
              isOutermostLevel: true,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              onRootChangedCallback: changeRoot,
            );
          },
        )));

        await tester.pumpAndSettle();
      }

      const windowSize = Size(2225.0, 1000.0);

      testWidgetsWithWindowSize(
        'builds treemap with expected data',
        windowSize,
        (WidgetTester tester) async {
          const treemapKey = Key('Treemap');
          await pumpTreemapWidget(tester, treemapKey);

          expect(find.byKey(treemapKey), findsOneWidget);

          await expectLater(
            find.byKey(treemapKey),
            matchesGoldenFile('goldens/treemap_v8.png'),
          );
          // Await delay for golden comparison.
          await tester.pumpAndSettle(const Duration(seconds: 2));
        },
        skip: kIsWeb || !Platform.isMacOS,
      );
    },
  );
}
