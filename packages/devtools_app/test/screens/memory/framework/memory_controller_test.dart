// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/class_filter.dart';
import 'package:devtools_app/src/shared/feature_flags.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../../../test_infra/scenes/memory/default.dart';

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

final classList = ClassList(
  classes: [
    ClassRef(id: 'cls/1', name: 'ClassA'),
    ClassRef(id: 'cls/2', name: 'ClassB'),
    ClassRef(id: 'cls/3', name: 'ClassC'),
    ClassRef(id: 'cls/4', name: 'Foo'),
  ],
);

Future<void> _pumpScene(WidgetTester tester, MemoryDefaultScene scene) async {
  await scene.pump(tester);
  await scene.goToDiffTab(tester);
}

// Set a wide enough screen width that we do not run into overflow.
const _windowSize = Size(2225.0, 1000.0);

void _verifyFiltersAreEqual(MemoryDefaultScene scene, [ClassFilter? filter]) {
  expect(
    scene.controller.diff.core.classFilter.value,
    equals(scene.controller.profile!.classFilter.value),
  );

  if (filter != null) {
    expect(scene.controller.diff.core.classFilter.value, equals(filter));
  }
}

void main() {
  late MemoryDefaultScene scene;
  late final CpuSamples allocationTracingProfile;

  setUpAll(() {
    final rawProfile =
        File(
          'test/test_infra/test_data/memory/allocation_tracing/allocation_trace.json',
        ).readAsStringSync();
    allocationTracingProfile = CpuSamples.parse(jsonDecode(rawProfile))!;
  });

  setUp(() async {
    scene = MemoryDefaultScene();
    await scene.setUp(classList: classList);
    mockConnectedApp(
      scene.fakeServiceConnection.serviceManager.connectedApp!,
      isFlutterApp: true,
      isProfileBuild: false,
      isWebApp: false,
    );

    final mockScriptManager = MockScriptManager();
    when(
      mockScriptManager.sortedScripts,
    ).thenReturn(ValueNotifier<List<ScriptRef>>([]));
    when(
      mockScriptManager.scriptRefForUri(any),
    ).thenReturn(ScriptRef(uri: 'package:test/script.dart', id: 'script.dart'));
    setGlobal(ScriptManager, mockScriptManager);
  });

  tearDown(() {
    scene.tearDown();
  });

  testWidgetsWithWindowSize(
    '$ClassFilter is shared between diff and profile.',
    _windowSize,
    (WidgetTester tester) async {
      await _pumpScene(tester, scene);
      await scene.takeSnapshot(tester);

      _verifyFiltersAreEqual(scene);

      scene.controller.diff.derived.applyFilter(_filter1);
      _verifyFiltersAreEqual(scene, _filter1);

      scene.controller.profile!.setFilter(_filter2);
      _verifyFiltersAreEqual(scene, _filter2);
    },
  );

  group('release memory', () {
    setUp(() {
      FeatureFlags.memoryObserver = true;
    });

    tearDown(() {
      FeatureFlags.memoryObserver = false;
    });

    testWidgetsWithWindowSize('releaseMemory - full release', _windowSize, (
      WidgetTester tester,
    ) async {
      await _pumpScene(tester, scene);

      // Add some data to the Diff view.
      await scene.takeSnapshot(tester);
      await scene.takeSnapshot(tester);

      // Add some data to the Trace view.
      await scene.goToTraceTab(tester);

      // Enable allocation tracing for one of them.
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      final tracingState = scene.controller.trace!.selection.value;
      final selectedTrace = tracingState.filteredClassList.value.firstWhere(
        (e) => e.traceAllocations,
      );
      final traceElement = find.byKey(Key(selectedTrace.clazz.id!));
      expect(traceElement, findsOneWidget);

      // Select the list item for the traced class and refresh to fetch data.
      await tester.tap(traceElement);
      await tester.pumpAndSettle();

      // Set fake sample data and refresh to populate the trace view.
      final fakeService =
          serviceConnection.serviceManager.service as FakeVmServiceWrapper;
      fakeService.allocationSamples = allocationTracingProfile;
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();

      expect(scene.controller.diff.hasSnapshots, true);
      expect(scene.controller.trace!.selection.value.profiles, isNotEmpty);
      await scene.controller.releaseMemory();
      expect(scene.controller.diff.hasSnapshots, false);
      expect(scene.controller.trace!.selection.value.profiles, isEmpty);
    });

    testWidgetsWithWindowSize('releaseMemory - partial release', _windowSize, (
      WidgetTester tester,
    ) async {
      await _pumpScene(tester, scene);

      // Add some data to the Diff view.
      await scene.takeSnapshot(tester);
      await scene.takeSnapshot(tester);
      await scene.takeSnapshot(tester);
      await scene.takeSnapshot(tester);

      // Full and partial releases are identical for the tracing functionality,
      // so we only need to check the diff behavior in this test case.
      expect(scene.controller.diff.hasSnapshots, true);
      expect(scene.controller.diff.core.snapshots.value.length, 5);
      await scene.controller.releaseMemory(partial: true);
      expect(scene.controller.diff.hasSnapshots, true);
      expect(scene.controller.diff.core.snapshots.value.length, 3);
    });

    testWidgetsWithWindowSize('succeeds with no snapshots', _windowSize, (
      WidgetTester tester,
    ) async {
      await _pumpScene(tester, scene);
      expect(scene.controller.diff.hasSnapshots, false);
      expect(scene.controller.diff.core.snapshots.value.length, 1);
      await scene.controller.releaseMemory();
      expect(scene.controller.diff.hasSnapshots, false);
      expect(scene.controller.diff.core.snapshots.value.length, 1);
    });
  });
}
