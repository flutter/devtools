// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/charts/treemap.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_snapshot_analysis/treemap.dart';

import '../test_infra/matchers/matchers.dart';
import '../test_infra/test_data/app_size/apk_analysis.dart';
import '../test_infra/test_data/app_size/new_v8.dart';
import '../test_infra/test_data/app_size/sizes.dart';
import '../test_infra/test_data/app_size/small_sizes.dart';

void main() {
  TreemapNode? root;

  void changeRoot(TreemapNode? newRoot) {
    root = newRoot;
  }

  // Pump treemap widget with tree built with test data.
  Future<void> pumpTreemapWidget(WidgetTester tester, Key treemapKey) async {
    await tester.pumpWidget(
      wrap(
        LayoutBuilder(
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
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const windowSize = Size(2225.0, 1000.0);

  setUp(() {
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
    setGlobal(IdeTheme, IdeTheme());
  });

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
    TreemapNode(name: 'libapp.so (Dart AOT)').addChild(
      nodeWithDuplicatePackageName
        ..addAllChildren([
          nodeWithDuplicatePackageNameChild1
            ..addChild(nodeWithDuplicatePackageNameGrandchild),
          nodeWithDuplicatePackageNameChild2,
        ]),
    );

    final dartLibraryChild = TreemapNode(name: 'dart lib child');
    final dartLibraryNode = TreemapNode(name: 'dart:core');
    TreemapNode(name: 'libapp.so (Dart AOT)')
        .addChild(dartLibraryNode..addChild(dartLibraryChild));

    test('packagePath returns correct values', () {
      expect(testRoot.packagePath(), equals([]));
      expect(grandchild1.packagePath(), equals(['package:child1']));
      expect(
        grandchild2.packagePath(),
        equals(['package:child2', 'package:grandchild2']),
      );
      expect(
        greatGrandchild1.packagePath(),
        equals(['package:child1', 'package:greatGrandchild1']),
      );
      expect(
        greatGrandchild2.packagePath(),
        equals([
          'package:child2',
          'package:grandchild2',
          'package:greatGrandchild2',
        ]),
      );
    });

    test('packagePath returns correct values for duplicate package name', () {
      expect(
        nodeWithDuplicatePackageNameGrandchild.packagePath(),
        equals(['package:a']),
      );
    });

    test('packagePath returns correct value for dart library node', () {
      expect(dartLibraryChild.packagePath(), equals(['dart:core']));
    });
  });

  group('Treemap from small instruction sizes', () {
    setUp(() async {
      root = await _loadSnapshotJsonAsTree(smallInstructionSizes);
    });
    testWidgetsWithWindowSize(
      'zooms in down to a node without children',
      windowSize,
      (WidgetTester tester) async {
        const treemapKey = Key('Treemap');
        await pumpTreemapWidget(tester, treemapKey);

        expect(find.richText('dart:_internal [0.3 KB]'), findsOneWidget);
        await tester.tap(find.richText('dart:_internal [0.3 KB]'));
        await tester.pumpAndSettle();

        await pumpTreemapWidget(tester, treemapKey);

        expect(find.richText('CastIterable [0.2 KB]'), findsOneWidget);
        await tester.tap(find.richText('CastIterable [0.2 KB]'));
        await tester.pumpAndSettle();

        await pumpTreemapWidget(tester, treemapKey);

        expect(find.richText('new CastIterable.\n[0.2 KB]'), findsOneWidget);
        await tester.tap(find.richText('new CastIterable.\n[0.2 KB]'));
        await tester.pumpAndSettle();

        await pumpTreemapWidget(tester, treemapKey);

        // TODO(jacobr): what text should be found in this case?
        // expect(find.text('new CastIterable. [0.2 KB]'), findsOneWidget);
      },
    );
  });

  group('Treemap from instruction sizes', () {
    setUp(() async {
      root = await _loadSnapshotJsonAsTree(instructionSizes);
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
          matchesDevToolsGolden('../test_infra/goldens/treemap_sizes.png'),
        );
      },
      skip: kIsWeb,
    );
  });

  group('Treemap from v8 snapshot', () {
    setUp(() async {
      root = await _loadSnapshotJsonAsTree(newV8);
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
          matchesDevToolsGolden('../test_infra/goldens/treemap_v8.png'),
        );
        // Await delay for golden comparison.
        await tester.pumpAndSettle(const Duration(seconds: 2));
      },
      skip: kIsWeb,
    );
  });

  group('Treemap from APK analysis', () {
    setUp(() async {
      root = await _loadSnapshotJsonAsTree(apkAnalysis);
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
          matchesDevToolsGolden('../test_infra/goldens/treemap_apk.png'),
        );
        // Await delay for golden comparison.
        await tester.pumpAndSettle(const Duration(seconds: 2));
      },
      skip: kIsWeb,
    );
  });
}

Future<TreemapNode> _loadSnapshotJsonAsTree(String snapshotJson) async {
  final treemapTestData = jsonDecode(snapshotJson);

  if (treemapTestData is Map<String, dynamic> &&
      treemapTestData['type'] == 'apk') {
    return _generateTree(treemapTestData);
  } else {
    final processedTestData = treemapFromJson(treemapTestData);
    processedTestData['n'] = 'Root';
    return _generateTree(processedTestData);
  }
}

/// Builds a tree with [TreemapNode] from [treeJson] which represents
/// the hierarchical structure of the tree.
TreemapNode _generateTree(Map<String, dynamic> treeJson) {
  var treemapNodeName = treeJson['n'];
  if (treemapNodeName == '') treemapNodeName = 'Unnamed';
  final rawChildren = treeJson['children'];
  final treemapNodeChildren = <TreemapNode>[];

  int treemapNodeSize = 0;
  if (rawChildren != null) {
    // If not a leaf node, build all children then take the sum of the
    // children's sizes as its own size.
    for (var child in rawChildren) {
      final childTreemapNode = _generateTree(child);
      treemapNodeChildren.add(childTreemapNode);
      treemapNodeSize += childTreemapNode.byteSize;
    }
    treemapNodeSize = treemapNodeSize;
  } else {
    // If a leaf node, just take its own size.
    // Defaults to 0 if a leaf node has a size of null.
    treemapNodeSize = treeJson['value'] ?? 0;
  }

  return TreemapNode(name: treemapNodeName, byteSize: treemapNodeSize)
    ..addAllChildren(treemapNodeChildren);
}
