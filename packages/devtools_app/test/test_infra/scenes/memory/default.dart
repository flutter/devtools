// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/controller/diff_pane_controller.dart';
import 'package:devtools_app/src/screens/memory/panes/profile/profile_pane_controller.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/class_filter.dart';
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
import '../scene_test_extensions.dart';

// To run:
// flutter run -t test/test_infra/scenes/memory/default.stager_app.g.dart -d macos

// ignore: avoid_classes_with_only_static_members, enum like classes are ok
abstract class MemoryDefaultSceneHeaps {
  /// Many instances of the same class with different long paths.
  ///
  /// If sorted by retaining path this class will be the second from the top.
  /// It is needed to measure if selection of this class will cause UI to jank.
  static Future<HeapSnapshotGraph> manyPaths() async {
    const pathLen = 100;
    const pathCount = 100;
    final result = FakeHeapSnapshotGraph();

    for (int i = 0; i < pathCount; i++) {
      final retainers = List<String>.generate(pathLen, (_) => 'Retainer$i');
      final index = result.addChain([...retainers, 'TheData']);
      result.objects[index].shallowSize = 10;
    }

    final heavyClassIndex = result.addChain(['HeavyClass']);
    result.objects[heavyClassIndex].shallowSize = 10000;
    return result;
  }

  static final List<HeapProvider> forDiffTesting = [
    {'A': 1, 'B': 2, 'C': 1},
    {'A': 1, 'B': 2},
    {'B': 1, 'C': 2, 'D': 3},
    {'B': 1, 'C': 2, 'D': 3},
  ]
      .map((e) => () async => FakeHeapSnapshotGraph()..addClassInstances(e))
      .toList();

  static final golden =
      // ignore: avoid-redundant-async, match signature
      goldenHeapTests.map((e) => () async => e.loadHeap()).toList();

  static List<HeapProvider> get all => [
        ...forDiffTesting,
        manyPaths,
        ...golden,
      ];
}

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

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpSceneAsync(this);
    // Delay to ensure the memory profiler has collected data.
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(MemoryBody), findsOneWidget);
  }

  @override

  /// Sets up the scene.
  ///
  /// [classList] will be returned by VmService.getClassList.
  /// [heapProviders] will be used to for heap snapshotting.
  Future<void> setUp({
    ClassList? classList,
    List<HeapProvider>? heapProviders,
  }) async {
    heapProviders = heapProviders ?? MemoryDefaultSceneHeaps.all;

    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(OfflineDataController, OfflineDataController());
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
    setGlobal(OfflineDataController, OfflineDataController());

    final showAllFilter = ClassFilter(
      filterType: ClassFilterType.showAll,
      except: '',
      only: '',
    );

    final diffController =
        DiffPaneController(loader: HeapGraphLoaderProvided(heapProviders))
          ..derived.applyFilter(showAllFilter);

    final profileController =
        ProfilePaneController(mode: ControllerCreationMode.connected)
          ..setFilter(showAllFilter);

    controller = MemoryController(
      connectedDiff: diffController,
      connectedProfile: profileController,
    );

    await controller.initialized;

    controller.chart.data.timeline.data
      ..clear()
      ..addAll(memoryJson.data);
  }

  @override
  String get title => '$MemoryDefaultScene';

  void tearDown() {}
}
