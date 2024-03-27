// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/memory/framework/connected/memory_tabs.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/class_filter.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_infra/scenes/memory/default.dart';
import '../../test_infra/scenes/scene_test_extensions.dart';

final _filter1 = ClassFilter(
  except: 'filter1',
  filterType: ClassFilterType.except,
  only: 'filter1',
);

final _filter2 = ClassFilter(
  except: 'filter2',
  filterType: ClassFilterType.except,
  only: 'filter2',
);

Future<void> pumpScene(WidgetTester tester, MemoryDefaultScene scene) async {
  await tester.pumpScene(scene);
  // Delay to ensure the memory profiler has collected data.
  await tester.pumpAndSettle(const Duration(seconds: 1));
  expect(find.byType(MemoryBody), findsOneWidget);
  await tester.tap(
    find.byKey(MemoryScreenKeys.diffTab),
  );
  await tester.pumpAndSettle();
}

Future<void> takeSnapshot(WidgetTester tester, MemoryDefaultScene scene) async {
  final snapshots = scene.controller.controllers.diff.core.snapshots;
  final length = snapshots.value.length;
  await tester.tap(find.byIcon(Icons.fiber_manual_record).first);
  await tester.pumpAndSettle();
  expect(snapshots.value.length, equals(length + 1));
}

// Set a wide enough screen width that we do not run into overflow.
const windowSize = Size(2225.0, 1000.0);

void _verifyFiltersAreEqual(MemoryDefaultScene scene, [ClassFilter? filter]) {
  expect(
    scene.controller.controllers.diff.core.classFilter.value,
    equals(scene.controller.controllers.profile.classFilter.value),
  );

  if (filter != null) {
    expect(
      scene.controller.controllers.diff.core.classFilter.value,
      equals(filter),
    );
  }
}

void main() {
  late MemoryDefaultScene scene;
  setUp(() async {
    scene = MemoryDefaultScene();
    await scene.setUp();
  });

  tearDown(() {
    scene.tearDown();
  });

  testWidgetsWithWindowSize(
    '$ClassFilter is shared between diff and profile.',
    windowSize,
    (WidgetTester tester) async {
      await pumpScene(tester, scene);
      await takeSnapshot(tester, scene);

      _verifyFiltersAreEqual(scene);

      scene.controller.controllers.diff.derived.applyFilter(_filter1);
      _verifyFiltersAreEqual(scene, _filter1);

      scene.controller.controllers.profile.setFilter(_filter2);
      _verifyFiltersAreEqual(scene, _filter2);
    },
  );
}
