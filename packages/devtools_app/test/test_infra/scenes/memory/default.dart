// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/controller/diff_pane_controller.dart';
import 'package:devtools_app/src/screens/memory/panes/profile/profile_pane_controller.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/class_filter.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/model.dart';
import 'package:devtools_app/src/shared/memory/adapted_heap_data.dart';
import 'package:devtools_app/src/shared/memory/adapted_heap_object.dart';
import 'package:devtools_app/src/shared/memory/class_name.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:stager/stager.dart';
import 'package:vm_service/vm_service.dart';

import '../../../test_infra/test_data/memory.dart';
import '../../../test_infra/test_data/memory/heap/heap_data.dart';
import '../../../test_infra/test_data/memory_allocation.dart';

/// To run:
/// flutter run -t test/test_infra/scenes/memory/default.stager_app.g.dart -d macos
class MemoryDefaultScene extends Scene {
  late MemoryController controller;
  late FakeServiceConnectionManager fakeServiceConnection;

  @override
  Widget build(BuildContext context) {
    return wrapWithControllers(
      const MemoryBody(),
      memory: controller,
    );
  }

  @override
  Future<void> setUp({ClassList? classList}) async {
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(OfflineModeController, OfflineModeController());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());
    setGlobal(BannerMessagesController, BannerMessagesController());
    setGlobal(
      PreferencesController,
      PreferencesController()..memory.showChart.value = false,
    );

    // Load canned data testHeapSampleData.
    final memoryJson =
        SamplesMemoryJson.decode(argJsonString: testHeapSampleData);
    final allocationJson =
        AllocationMemoryJson.decode(argJsonString: testAllocationData);

    fakeServiceConnection = FakeServiceConnectionManager(
      service: FakeServiceManager.createFakeService(
        memoryData: memoryJson,
        allocationData: allocationJson,
        classList: classList,
      ),
    );
    final app = fakeServiceConnection.serviceManager.connectedApp!;
    mockConnectedApp(
      app,
      isFlutterApp: true,
      isProfileBuild: true,
      isWebApp: false,
    );
    when(fakeServiceConnection.serviceManager.vm.operatingSystem)
        .thenReturn('ios');
    setGlobal(ServiceConnectionManager, fakeServiceConnection);

    final showAllFilter = ClassFilter(
      filterType: ClassFilterType.showAll,
      except: '',
      only: '',
    );

    final diffController = DiffPaneController(_TestSnapshotTaker())
      ..derived.applyFilter(showAllFilter);

    final profileController = ProfilePaneController()..setFilter(showAllFilter);

    controller = MemoryController(
      diffPaneController: diffController,
      profilePaneController: profileController,
    )
      ..offline = true
      ..controllers.memoryTimeline.offlineData.clear()
      ..controllers.memoryTimeline.offlineData.addAll(memoryJson.data);
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
      objects[rootIndex].outRefs.add(objectIndex);
    }
  }

  return AdaptedHeapData(
    objects,
    rootIndex: rootIndex,
  );
}

var _nextCode = 1;

AdaptedHeapObject _createObject(String className) => AdaptedHeapObject(
      code: _nextCode++,
      outRefs: {},
      heapClass: HeapClassName.fromPath(
        className: className,
        library: 'my_lib',
      ),
      shallowSize: 80, // 10 bytes
    );
