// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/panes/diff/diff_pane.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/widgets/class_filter_dialog.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/widgets/snapshot_control_pane.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/class_filter.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../matchers/matchers.dart';
import '../../../scenes/memory/diff_snapshot.dart';

void main() {
  late DiffSnapshotScene scene;

  Future<void> pumpScene(WidgetTester tester) async {
    await tester.pumpWidget(scene.build());
    await expectLater(
      find.byType(SnapshotInstanceItemPane),
      matchesDevToolsGolden('../../../goldens/memory_diff_snapshot_scene.png'),
    );
    expect(
      scene.diffController.core.snapshots.value
          .where((element) => element.hasData),
      hasLength(2),
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
      '$ClassFilterDialog customizes resets to default', windowSize,
      (WidgetTester tester) async {
    await pumpScene(tester);

    // Customize filter.
    scene.diffController.applyFilter(
      ClassFilter(filterType: ClassFilterType.only, except: '', only: ''),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(SnapshotInstanceItemPane),
      matchesDevToolsGolden(
        '../../../goldens/memory_diff_filter_snapshot_custom.png',
      ),
    );

    // Open dialog.
    await tester.tap(find.byType(ClassFilterButton));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ClassFilterDialog),
      matchesDevToolsGolden(
        '../../../goldens/memory_diff_filter_dialog_custom.png',
      ),
    );

    // Reset to default.
    await tester.tap(find.text('Reset to default'));
    await _checkFilterGolden(ClassFilterType.showAll, tester);

    // Close dialog.
    await tester.tap(find.text('APPLY'));
    await _checkDataGolden(ClassFilterType.showAll, tester);
  });
}

Future<void> _checkFilterGolden(
  ClassFilterType type,
  WidgetTester tester,
) async {
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(ClassFilterDialog),
    matchesDevToolsGolden(
      '../../../goldens/memory_diff_filter_dialog_${type.name}.png',
    ),
  );
}

Future<void> _checkDataGolden(
  ClassFilterType type,
  WidgetTester tester,
) async {
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(SnapshotInstanceItemPane),
    matchesDevToolsGolden(
      '../../../goldens/memory_diff_snapshot_${type.name}.png',
    ),
  );
}

/// Verifies original and new state of filter and data.
Future<void> _switchFilter(
  ClassFilterType from,
  ClassFilterType to,
  WidgetTester tester,
) async {
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
