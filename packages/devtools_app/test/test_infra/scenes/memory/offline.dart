// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/memory/framework/memory_tabs.dart';
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
import '../scene_test_extensions.dart';

class MemoryOfflineScene extends Scene {
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

    final diffController = DiffPaneController(
      loader: null,
      rootPackage: 'root',
    )..derived.applyFilter(showAllFilter);

    final profileController = ProfilePaneController(
      mode: ControllerCreationMode.connected,
      rootPackage: 'root',
    )..setFilter(showAllFilter);

    controller = MemoryController(
      connectedDiff: diffController,
      connectedProfile: profileController,
    );

    await controller.initialized;

    controller.chart!.data.timeline.data
      ..clear()
      ..addAll(memoryJson.data);
  }

  @override
  String get title => '$MemoryOfflineScene';

  Future<void> goToDiffTab(WidgetTester tester) async {
    await tester.tap(find.byKey(MemoryScreenKeys.diffTab));
    await tester.pumpAndSettle();
  }

  Future<void> goToTraceTab(WidgetTester tester) async {
    await tester.tap(find.byKey(MemoryScreenKeys.traceTab));
    await tester.pumpAndSettle();
  }

  void tearDown() {}
}
