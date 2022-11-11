// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/screens/memory/memory_controller.dart';
import 'package:devtools_app/src/screens/memory/memory_screen.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/controller/diff_pane_controller.dart';
import 'package:devtools_app/src/screens/memory/primitives/class_name.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/model.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_app/src/shared/preferences.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stager/stager.dart';

import '../../test_data/memory.dart';
import '../../test_data/memory/heap/heap_data.dart';
import '../../test_data/memory_allocation.dart';

/// To run:
/// flutter run -t test/scenes/memory/default.stager_app.dart -d macos
class MemoryDefaultScene extends Scene {
  late MemoryController controller;
  late FakeServiceManager fakeServiceManager;

  @override
  Widget build() {
    return wrapWithControllers(
      const MemoryBody(),
      memory: controller,
    );
  }

  @override
  Future<void> setUp() async {
    await ensureInspectorDependencies();
    setGlobal(OfflineModeController, OfflineModeController());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());
    setGlobal(
      PreferencesController,
      PreferencesController()..memory.showChart.value = false,
    );

    // Load canned data testHeapSampleData.
    final memoryJson =
        SamplesMemoryJson.decode(argJsonString: testHeapSampleData);
    final allocationJson =
        AllocationMemoryJson.decode(argJsonString: testAllocationData);

    fakeServiceManager = FakeServiceManager(
      service: FakeServiceManager.createFakeService(
        memoryData: memoryJson,
        allocationData: allocationJson,
      ),
    );
    final app = fakeServiceManager.connectedApp!;
    mockConnectedApp(
      app,
      isFlutterApp: true,
      isProfileBuild: true,
      isWebApp: false,
    );
    setGlobal(ServiceConnectionManager, fakeServiceManager);

    controller = MemoryController(
      diffPaneController: DiffPaneController(_TestSnapshotTaker()),
    )
      ..offline.value = true
      ..memoryTimeline.offlineData.clear()
      ..memoryTimeline.offlineData.addAll(memoryJson.data);
  }

  @override
  String get title => '$MemoryDefaultScene';

  void tearDown() {}
}

/// Provides test snapshots. First time returns null.
class _TestSnapshotTaker implements SnapshotTaker {
  bool firstTime = true;
  int index = -1;

  @override
  Future<AdaptedHeapData?> take() async {
    // This delay is needed for UI to start showing the progress indicator.
    await Future.delayed(const Duration(milliseconds: 100));

    // Return null if it is the first time to test cover the edge case.
    if (firstTime) {
      firstTime = false;
      return null;
    }

    index = (index + 1) % (_simpleHeapTests.length + goldenHeapTests.length);

    // Return simple test.
    if (index < _simpleHeapTests.length) return _simpleHeapTests[index];

    return await goldenHeapTests[index - _simpleHeapTests.length].loadHeap();
  }
}

final _simpleHeapTests = <AdaptedHeapData>[
  _createHeap({'A': 1, 'B': 2}),
  _createHeap({'B': 1, 'C': 2, 'D': 3}),
  _createHeap({'B': 1, 'C': 2, 'D': 3}),
];

AdaptedHeapData _createHeap(Map<String, int> classToInstanceCount) {
  const rootIndex = 0;
  final objects = <AdaptedHeapObject>[_createObject('root')];
  var leafCount = 0;

  // Create objects.
  for (var entry in classToInstanceCount.entries) {
    for (var _ in Iterable.generate(entry.value)) {
      objects.add(_createObject(entry.key));
      leafCount++;
      final objectIndex = leafCount;
      objects[rootIndex].references.add(objectIndex);
    }
  }

  return AdaptedHeapData(objects, rootIndex: rootIndex);
}

var _nextCode = 1;

AdaptedHeapObject _createObject(String className) => AdaptedHeapObject(
      code: _nextCode++,
      references: [],
      heapClass: HeapClassName(
        className: className,
        library: 'my_lib',
      ),
      shallowSize: 80, // 10 bytes
    );
