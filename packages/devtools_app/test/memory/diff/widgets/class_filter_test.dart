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

void main() {
  late DiffSnapshotScene scene;

  Future<void> pumpScene(WidgetTester tester, {bool isDiff = false}) async {
    final diffing = isDiff ? 'diff' : 'single';

    expect(
      scene.diffController.core.snapshots.value
          .where((element) => element.hasData),
      hasLength(2),
    );

    if (isDiff) {
      scene.diffController.setDiffing(
        scene.diffController.derived.selectedItem.value as SnapshotInstanceItem,
        scene.diffController.core.snapshots.value[1] as SnapshotInstanceItem,
      );
    }

    await tester.pumpWidget(scene.build());
    await expectLater(
      find.byType(SnapshotInstanceItemPane),
      matchesDevToolsGolden(
        '../../../goldens/memory_diff_snapshot_scene_$diffing.png',
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

  testWidgetsWithWindowSize('$ClassFilterDialog filters classes', windowSize,
      (WidgetTester tester) async {
    await pumpScene(tester);

    await _switchFilter(
      ClassFilterType.showAll,
      ClassFilterType.except,
      tester,
    );
    await _switchFilter(ClassFilterType.except, ClassFilterType.only, tester);
    await _switchFilter(ClassFilterType.only, ClassFilterType.showAll, tester);
  });

  testWidgetsWithWindowSize(
      '$ClassFilterDialog customizes and resets to default', windowSize,
      (WidgetTester tester) async {
    await pumpScene(tester);

    // Customize filter.
    scene.diffController.applyFilter(_customFilter);
    await _checkDataGolden(null, tester);

    // Open dialog.
    await tester.tap(find.byType(ClassFilterButton));
    await _checkFilterGolden(null, tester);

    // Reset to default.
    await tester.tap(find.text('Reset to default'));
    await _checkFilterGolden(ClassFilterType.showAll, tester);

    // Close dialog.
    await tester.tap(find.text('APPLY'));
    await _checkDataGolden(ClassFilterType.showAll, tester);
  });
}

/// If type is null, fileter is [_customFilter].
Future<void> _checkFilterGolden(ClassFilterType? type, WidgetTester tester,
    {bool isDiff = false}) async {
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(ClassFilterDialog),
    matchesDevToolsGolden(
      '../../../goldens/memory_diff_filter_dialog_${type?.name ?? "custom"}.png',
    ),
  );
}

/// If type is null, fileter is [_customFilter].
Future<void> _checkDataGolden(ClassFilterType? type, WidgetTester tester,
    {bool isDiff = false}) async {
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(SnapshotInstanceItemPane),
    matchesDevToolsGolden(
      '../../../goldens/memory_diff_snapshot_${type?.name ?? "custom"}.png',
    ),
  );
}

/// Verifies original and new state of filter and data.
Future<void> _switchFilter(
  ClassFilterType from,
  ClassFilterType to,
  WidgetTester tester, {
  bool isDiff: false,
}) async {
  await _checkDataGolden(from, tester);

  // Open dialog.
  await tester.tap(find.byType(ClassFilterButton));
  await _checkFilterGolden(from, tester);

  // Select new filter.
  await tester.tap(find.byKey(Key(to.toString())));
  await _checkFilterGolden(to, tester);

  // Close dialog.
  await tester.tap(find.text('APPLY'));

  await _checkDataGolden(to, tester);
}
