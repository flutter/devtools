// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/memory/framework/memory_tabs.dart';
import 'package:devtools_app/src/screens/memory/framework/offline_data/offline_data.dart';
import 'package:devtools_app/src/shared/file_import.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/helpers.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stager/stager.dart';
import 'package:vm_service/vm_service.dart';

import '../../test_data/memory/heap/heap_data.dart';
import '../scene_test_extensions.dart';

// To run:
// flutter run -t test/test_infra/scenes/memory/offline.stager_app.g.dart -d macos

class MemoryOfflineScene extends Scene {
  final controller = ValueNotifier<MemoryController?>(null);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (_, value, ___) {
        if (value == null) {
          return const CircularProgressIndicator();
        }
        return wrapWithControllers(
          const MemoryBody(),
          memory: value,
        );
      },
    );
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpSceneAsync(this);
    // Delay to ensure the memory profiler has collected data.
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(MemoryBody), findsOneWidget);
  }

  /// Sets up the scene.
  ///
  /// [classList] will be returned by VmService.getClassList.
  /// [heapProviders] will be used to for heap snapshotting.
  @override
  Future<void> setUp({
    ClassList? classList,
    List<HeapProvider>? heapProviders,
  }) async {
    print('!!! MemoryOfflineScene setUp1');
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
    print('!!! MemoryOfflineScene setUp2');

    final file = XFile(
      'test/test_infra/test_data/memory/offline/memory_offline_data.json',
    );
    final importedFile = await toDevToolsFile(file);

    // // Provider.of<ImportController>(context, listen: false)
    // //     .importData(importedFile, expectedScreenId: screenId);

    print('!!! MemoryOfflineScene setUp3');
    final json = importedFile.data as Map<String, dynamic>;
    final data = MemoryController.createData(json[ScreenMetaData.memory.id]);
    print('!!! MemoryOfflineScene setUp4');
    controller.value = MemoryController(data: data);
    print('!!! MemoryOfflineScene setUp, controller');
    await controller.value!.initialized;
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
