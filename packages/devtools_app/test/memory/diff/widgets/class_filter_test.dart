// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/panes/diff/controller/item_controller.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/diff_pane.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/widgets/class_filter_dialog.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/widgets/snapshot_control_pane.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/class_filter.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../matchers/matchers.dart';
import '../../../scenes/memory/diff_snapshot.dart';

final _customFilter =
    ClassFilter(filterType: ClassFilterType.only, except: '', only: '');

class _FilterTest {
  _FilterTest(this.isDiff);

  final bool isDiff;
  String get name => isDiff ? 'diff' : 'single';
}

final _tests = [_FilterTest(false), _FilterTest(true)];

void main() {
  late DiffSnapshotScene scene;

  Future<void> pumpScene(WidgetTester tester, _FilterTest test) async {
    expect(
      scene.diffController.core.snapshots.value
          .where((element) => element.hasData),
      hasLength(2),
    );

    if (test.isDiff) {
      scene.diffController.setDiffing(
        scene.diffController.derived.selectedItem.value as SnapshotInstanceItem,
        scene.diffController.core.snapshots.value[1] as SnapshotInstanceItem,
      );
    }

    await tester.pumpWidget(scene.build());
    await expectLater(
      find.byType(SnapshotInstanceItemPane),
      matchesDevToolsGolden(
        '../../../goldens/memory_diff_snapshot_scene_${test.name}.png',
      ),
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

  for (var t in _tests) {
    testWidgetsWithWindowSize(
        '$ClassFilterDialog filters classes, ${t.name}', windowSize,
        (WidgetTester tester) async {
      await pumpScene(tester, t);

      await _switchFilter(
        ClassFilterType.showAll,
        ClassFilterType.except,
        tester,
        t,
      );

      await _switchFilter(
        ClassFilterType.except,
        ClassFilterType.only,
        tester,
        t,
      );

      await _switchFilter(
        ClassFilterType.only,
        ClassFilterType.showAll,
        tester,
        t,
      );
    });
  }

  for (var t in _tests) {
    testWidgetsWithWindowSize(
        '$ClassFilterDialog customizes and resets to default, ${t.name}',
        windowSize, (WidgetTester tester) async {
      await pumpScene(tester, t);

      // Customize filter.
      scene.diffController.applyFilter(_customFilter);
      await _checkDataGolden(null, tester, t);

      // Open dialog.
      await tester.tap(find.byType(ClassFilterButton));
      await _checkFilterGolden(null, tester);

      // Reset to default.
      await tester.tap(find.text('Reset to default'));
      await _checkFilterGolden(ClassFilterType.showAll, tester);

      // Close dialog.
      await tester.tap(find.text('APPLY'));
      await _checkDataGolden(ClassFilterType.showAll, tester, t);
    });
  }
}

/// If type is null, fileter is [_customFilter].
Future<void> _checkFilterGolden(
  ClassFilterType? type,
  WidgetTester tester,
) async {
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(ClassFilterDialog),
    matchesDevToolsGolden(
      '../../../goldens/memory_diff_filter_dialog_${type?.name ?? "custom"}.png',
    ),
  );
}

/// If type is null, fileter is [_customFilter].
Future<void> _checkDataGolden(
  ClassFilterType? type,
  WidgetTester tester,
  _FilterTest test,
) async {
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(SnapshotInstanceItemPane),
    matchesDevToolsGolden(
      '../../../goldens/memory_diff_snapshot_${type?.name ?? "custom"}_${test.name}.png',
    ),
  );
}

/// Verifies original and new state of filter and data.
Future<void> _switchFilter(
  ClassFilterType from,
  ClassFilterType to,
  WidgetTester tester,
  _FilterTest test,
) async {
  await _checkDataGolden(from, tester, test);

  // Open dialog.
  await tester.tap(find.byType(ClassFilterButton));
  await _checkFilterGolden(from, tester);

  // Select new filter.
  await tester.tap(find.byKey(Key(to.toString())));
  await _checkFilterGolden(to, tester);

  // Close dialog.
  await tester.tap(find.text('APPLY'));

  await _checkDataGolden(to, tester, test);
}
