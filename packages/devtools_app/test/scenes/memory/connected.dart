import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/screens/memory/memory_controller.dart';
import 'package:devtools_app/src/screens/memory/memory_heap_tree_view.dart';
import 'package:devtools_app/src/screens/memory/memory_screen.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/diff_pane.dart';
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
import '../../test_data/memory_allocation.dart';

/// To run:
/// flutter run -t test/scenes/memory/connected.stager_app.dart -d macos
class MemoryConnectedScene extends Scene {
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
    enableNewAllocationProfileTable = true;
    shouldShowDiffPane = true;

    await ensureInspectorDependencies();
    setGlobal(OfflineModeController, OfflineModeController());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());
    setGlobal(PreferencesController, PreferencesController());

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

    controller = MemoryController()
      ..offline.value = true
      ..memoryTimeline.offlineData.clear()
      ..memoryTimeline.offlineData.addAll(memoryJson.data);
  }

  @override
  String get title => '$MemoryConnectedScene';

  void tearDown() {
    enableNewAllocationProfileTable = false;
    shouldShowDiffPane = false;
  }
}
