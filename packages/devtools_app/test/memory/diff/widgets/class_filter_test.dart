// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/panes/diff/controller/item_controller.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/diff_pane.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/class_filter.dart';
import 'package:devtools_app/src/screens/memory/shared/widgets/class_filter.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_infra/matchers/matchers.dart';
import '../../../test_infra/scenes/memory/diff_snapshot.dart';
import '../../../test_infra/scenes/scene_test_extensions.dart';

class _FilterTest {
  _FilterTest({required this.isDiff});

  final bool isDiff;

  String get name => isDiff ? 'diff' : 'single';

  String get sceneGolden =>
      '../../../test_infra/goldens/memory_diff_snapshot_scene_$name.png';
  String snapshotGolden(ClassFilterType? type) =>
      '../../../test_infra/goldens/memory_diff_snapshot_${type?.name ?? 'custom'}_$name.png';
  static String dialogGolden(ClassFilterType? type) =>
      '../../../test_infra/goldens/memory_diff_filter_dialog_${type?.name ?? 'custom'}.png';
}

final _tests = [
  _FilterTest(isDiff: false),
  _FilterTest(isDiff: true),
];

final _customFilter = ClassFilter(
  filterType: ClassFilterType.only,
  except: '',
  only: '',
);

void main() {
  group('Class Filter', () {
    late DiffSnapshotScene scene;

    setUp(() async {
      scene = DiffSnapshotScene();
      await scene.setUp();
    });

    Future<DiffSnapshotScene> pumpScene(
      WidgetTester tester,
      _FilterTest test,
    ) async {
      scene.setClassFilterToShowAll();

      expect(
        scene.diffController.core.snapshots.value
            .where((element) => element.hasData),
        hasLength(2),
      );

      final diffWith = test.isDiff
          ? scene.diffController.core.snapshots.value[1] as SnapshotDataItem
          : null;

      scene.diffController.setDiffing(
        scene.diffController.derived.selectedItem.value as SnapshotDataItem,
        diffWith,
      );

      await tester.pumpScene(scene);
      await tester.pumpAndSettle();
      expect(
        scene.diffController.core.classFilter.value.filterType,
        ClassFilterType.showAll,
      );
      await expectLater(
        find.byType(SnapshotInstanceItemPane),
        matchesDevToolsGolden(test.sceneGolden),
      );

      return scene;
    }

    // Set a wide enough screen width that we do not run into overflow.
    const windowSize = Size(2225.0, 1000.0);

    for (final test in _tests) {
      testWidgetsWithWindowSize(
        '$ClassFilterDialog filters classes, ${test.name}',
        windowSize,
        (WidgetTester tester) async {
          final scene = await pumpScene(tester, test);

          await _switchFilter(
            scene,
            ClassFilterType.showAll,
            ClassFilterType.except,
            tester,
            test,
          );

          await _switchFilter(
            scene,
            ClassFilterType.except,
            ClassFilterType.only,
            tester,
            test,
          );

          await _switchFilter(
            scene,
            ClassFilterType.only,
            ClassFilterType.showAll,
            tester,
            test,
          );
        },
      );
    }

    for (final test in _tests) {
      testWidgetsWithWindowSize(
        '$ClassFilterDialog customizes and resets to default, ${test.name}',
        windowSize,
        (WidgetTester tester) async {
          final scene = await pumpScene(tester, test);

          // Customize filter.
          scene.diffController.derived.applyFilter(_customFilter);
          await _checkDataGolden(scene, null, tester, test);

          // Open dialog.
          await tester.tap(find.byType(ClassFilterButton));
          await _checkFilterGolden(null, tester);

          // Reset to default.
          await tester.tap(find.text('Reset to default'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('APPLY'));
          await tester.pumpAndSettle();
          await tester.pumpAndSettle();

          final actualFilter = scene.diffController.core.classFilter.value;
          expect(actualFilter.filterType, equals(ClassFilterType.except));
          expect(actualFilter.except, equals(ClassFilter.defaultExceptString));
        },
      );
    }
  });
}

/// Verifies original and new state of filter and data.
Future<void> _switchFilter(
  DiffSnapshotScene scene,
  ClassFilterType from,
  ClassFilterType to,
  WidgetTester tester,
  _FilterTest test,
) async {
  await _checkDataGolden(scene, from, tester, test);

  // Open dialog.
  await tester.tap(find.byType(ClassFilterButton));
  await _checkFilterGolden(from, tester);

  // Select new filter.
  final radioButton = find.byKey(Key(to.toString()));
  await tester.tap(radioButton);
  await _checkFilterGolden(to, tester);

  // Close dialog.
  await tester.tap(find.text('APPLY'));

  await _checkDataGolden(scene, to, tester, test);
}

/// If type is null, filter is [_customFilter].
Future<void> _checkFilterGolden(
  ClassFilterType? type,
  WidgetTester tester,
) async {
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(ClassFilterDialog),
    matchesDevToolsGolden(_FilterTest.dialogGolden(type)),
  );
}

/// If type is null, filter is [_customFilter].
Future<void> _checkDataGolden(
  DiffSnapshotScene scene,
  ClassFilterType? type,
  WidgetTester tester,
  _FilterTest test,
) async {
  await tester.pumpAndSettle();

  final currentFilterType =
      scene.diffController.core.classFilter.value.filterType;
  expect(currentFilterType, type ?? _customFilter.filterType);

  await expectLater(
    find.byType(SnapshotInstanceItemPane),
    matchesDevToolsGolden(test.snapshotGolden(type)),
  );
}
