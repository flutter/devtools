// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/panes/tracing/tracing_pane_controller.dart';

import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/memory/framework/memory_tabs.dart';
import 'package:devtools_app/src/screens/memory/panes/tracing/tracing_pane_controller.dart';
import 'package:devtools_app/src/screens/memory/panes/tracing/tracing_tree.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../../test_infra/scenes/memory/default.dart';
import '../../test_infra/utils/test_utils.dart';

final classList = ClassList(
  classes: [
    ClassRef(id: 'cls/1', name: 'ClassA'),
    ClassRef(id: 'cls/2', name: 'ClassB'),
    ClassRef(id: 'cls/3', name: 'ClassC'),
    ClassRef(id: 'cls/4', name: 'Foo'),
  ],
);

/// Clears the class filter text field.
Future<void> clearFilter(
  WidgetTester tester,
  TracingPaneController controller,
) async {
  final originalClassCount = classList.classes!.length;
  final clearFilterButton = find.byIcon(Icons.clear);
  expect(clearFilterButton, findsOneWidget);
  await tester.tap(clearFilterButton);
  await tester.pumpAndSettle();
  expect(
    controller.stateForIsolate.value.filteredClassList.value.length,
    originalClassCount,
  );
}

// Set a wide enough screen width that we do not run into overflow.
const windowSize = Size(2225.0, 1000.0);

void main() {
  late MemoryDefaultScene scene;

  late final CpuSamples allocationTracingProfile;

  Future<void> pumpScene(WidgetTester tester) async {
    await scene.pump(tester);
    await tester.tap(
      find.byKey(MemoryScreenKeys.traceTab),
    );
    await tester.pumpAndSettle();
  }

  setUpAll(() {
    final rawProfile = File(
      'test/test_infra/test_data/memory/allocation_tracing/allocation_trace.json',
    ).readAsStringSync();
    allocationTracingProfile = CpuSamples.parse(jsonDecode(rawProfile))!;
  });

  setUp(() async {
    setCharacterWidthForTables();

    scene = MemoryDefaultScene();
    await scene.setUp(classList: classList);
    mockConnectedApp(
      scene.fakeServiceConnection.serviceManager.connectedApp!,
      isFlutterApp: true,
      isProfileBuild: false,
      isWebApp: false,
    );

    final mockScriptManager = MockScriptManager();
    when(mockScriptManager.sortedScripts).thenReturn(
      ValueNotifier<List<ScriptRef>>([]),
    );
    when(mockScriptManager.scriptRefForUri(any)).thenReturn(
      ScriptRef(
        uri: 'package:test/script.dart',
        id: 'script.dart',
      ),
    );
    setGlobal(ScriptManager, mockScriptManager);
  });

  tearDown(() {
    scene.tearDown();
  });

  // testWidgetsWithWindowSize(
  //   'basic tracing flow',
  //   windowSize,
  //   (WidgetTester tester) async {
  //     await pumpScene(tester);
  //     await scene.goToTraceTab(tester);

  //     final controller = scene.controller.trace!;

  //     final json = controller.toJson();
  //     expect(
  //       json.keys.toSet(),
  //       equals(diff_pane_controller.Json.values.map((e) => e.name).toSet()),
  //     );
  //     final fromJson = DiffPaneController.fromJson(json);

  //     final snapshotsFromJson =
  //         fromJson.core.snapshots.value.whereType<SnapshotDataItem>();

  //     expect(snapshotsFromJson.length, 2);
  //     expect(
  //       snapshotsFromJson.first.diffWith.value == snapshotsFromJson.last,
  //       true,
  //     );
  //     expect(snapshotsFromJson.last.diffWith.value, null);

  //     expect(snapshotsFromJson.first.name, snapshots.first.name);
  //     expect(snapshotsFromJson.last.name, snapshots.last.name);
  //   },
  // );
}
