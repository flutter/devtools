// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:devtools_app/src/charts/treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

import 'support/app_size_test_data/apk_analysis.dart';
import 'support/app_size_test_data/new_v8.dart';
import 'support/app_size_test_data/sizes.dart';
import 'support/app_size_test_data/small_sizes.dart';
import 'support/utils.dart';
import 'support/wrappers.dart';

void main() {
  TreemapNode root;

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
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          onRootChangedCallback: changeRoot,
        );
      },
    )));
    await tester.pumpAndSettle();
  }

  const windowSize = Size(2225.0, 1000.0);

  group('TreemapNode', () {
    final child1 = TreemapNode(name: 'package:child1');
    final child2 = TreemapNode(name: 'package:child2');
    final grandchild1 = TreemapNode(name: 'non-package-grandchild');
    final grandchild2 = TreemapNode(name: 'package:grandchild2');
    final greatGrandchild1 = TreemapNode(name: 'package:greatGrandchild1');
    final greatGrandchild2 = TreemapNode(name: 'package:greatGrandchild2');
    final testRoot = TreemapNode(name: 'libapp.so (Dart AOT)')
      ..addAllChildren([
        child1
          ..addChild(
            grandchild1
              ..addChild(
                greatGrandchild1,
              ),
          ),
        child2
          ..addChild(
            grandchild2
              ..addChild(
                greatGrandchild2,
              ),
          ),
      ]);

    final nodeWithDuplicatePackageNameGrandchild =
        TreemapNode(name: 'grandchild');
    final nodeWithDuplicatePackageNameChild1 = TreemapNode(name: 'package:a');
    final nodeWithDuplicatePackageNameChild2 = TreemapNode(name: '<Type>');
    final nodeWithDuplicatePackageName = TreemapNode(name: 'package:a');
    TreemapNode(name: 'libapp.so (Dart AOT)')
      ..addChild(nodeWithDuplicatePackageName
        ..addAllChildren([
          nodeWithDuplicatePackageNameChild1
            ..addChild(nodeWithDuplicatePackageNameGrandchild),
          nodeWithDuplicatePackageNameChild2,
        ]));

    final dartLibraryChild = TreemapNode(name: 'dart lib child');
    final dartLibraryNode = TreemapNode(name: 'dart:core');
    TreemapNode(name: 'libapp.so (Dart AOT)')
      ..addChild(dartLibraryNode..addChild(dartLibraryChild));

    test('packagePath returns correct values', () {
      expect(testRoot.packagePath(), equals([]));
      expect(grandchild1.packagePath(), equals(['package:child1']));
      expect(grandchild2.packagePath(),
          equals(['package:child2', 'package:grandchild2']));
      expect(greatGrandchild1.packagePath(),
          equals(['package:child1', 'package:greatGrandchild1']));
      expect(
          greatGrandchild2.packagePath(),
          equals([
            'package:child2',
            'package:grandchild2',
            'package:greatGrandchild2',
          ]));
    });

    test('packagePath returns correct values for duplicate package name', () {
      expect(nodeWithDuplicatePackageNameGrandchild.packagePath(),
          equals(['package:a']));
    });

    test('packagePath returns correct value for dart library node', () {
      expect(dartLibraryChild.packagePath(), equals(['dart:core']));
    });
  });

  group('Treemap from small instruction sizes', () {
    setUp(() async {
      root = await loadSnapshotJsonAsTree(smallInstructionSizes);
    });
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
  });

  group('Treemap from instruction sizes', () {
    setUp(() async {
      root = await loadSnapshotJsonAsTree(instructionSizes);
    });

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
  });

  group('Treemap from v8 snapshot', () {
    setUp(() async {
      root = await loadSnapshotJsonAsTree(newV8);
    });

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
  });

  group('Treemap from APK analysis', () {
    setUp(() async {
      root = await loadSnapshotJsonAsTree(apkAnalysis);
    });

    testWidgetsWithWindowSize(
      'builds treemap with expected data',
      windowSize,
      (WidgetTester tester) async {
        const treemapKey = Key('Treemap');
        await pumpTreemapWidget(tester, treemapKey);

        expect(find.byKey(treemapKey), findsOneWidget);

        await expectLater(
          find.byKey(treemapKey),
          matchesGoldenFile('goldens/treemap_apk.png'),
        );
        // Await delay for golden comparison.
        await tester.pumpAndSettle(const Duration(seconds: 2));
      },
      skip: kIsWeb || !Platform.isMacOS,
    );
  });
}
