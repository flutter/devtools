// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/controller/diff_pane_controller.dart';
import 'package:devtools_app/src/screens/memory/panes/profile/profile_pane_controller.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/class_filter.dart';
import 'package:devtools_app/src/shared/memory/class_name.dart';
import 'package:devtools_app/src/shared/memory/heap_graph_loader.dart';
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
import '../../../test_infra/test_data/memory_allocation.dart';
import '../../test_data/memory/heap/heap_data.dart';
import '../../test_data/memory/heap/heap_graph_fakes.dart';

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

    final diffController = DiffPaneController(createHeapLoader())
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

  HeapGraphLoader createHeapLoader() {
    final simpleHeaps = [
      {'A': 1, 'B': 2, 'C': 1},
      {'A': 1, 'B': 2},
      {'B': 1, 'C': 2, 'D': 3},
      {'B': 1, 'C': 2, 'D': 3},
    ]
        .map((e) => () async => HeapSnapshotGraphFake()..addClassInstances(e))
        .toList();

    /// 100 instances of the same class with different paths of length 100.
    Future<HeapSnapshotGraphFake> manyPaths() async {
      final result = HeapSnapshotGraphFake();
      final basePath = List<String>.generate(100, (i) => 'Referrer[i]');

      for (int i = 0; i < 100; i++) {
        result.addChain([...basePath, 'Owner$i', 'TheData']);
      }
      final selection = result.add();
      result.objects[selection]
        ..classId = result
            .maybeAddClass(HeapClassName(library: '', className: 'HeavyClass'))!
        ..shallowSize = 10000;

      return result;
    }

    final goldenHeaps =
        // ignore: avoid-redundant-async, match signature
        goldenHeapTests.map((e) => () async => e.loadHeap()).toList();

    return HeapGraphLoaderProvided([
      ...simpleHeaps,
      manyPaths,
      ...goldenHeaps,
    ]);
  }

  void tearDown() {}
}
