// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/file_import.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
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
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());

    final file = XFile(
      'test/test_infra/test_data/memory/offline/memory_offline_data.json',
    );
    final importedFile = await toDevToolsFile(file);

    final json = importedFile.data as Map<String, dynamic>;
    final data = MemoryController.createData(json[ScreenMetaData.memory.id]);
    controller.value = MemoryController(data: data);
    await controller.value!.initialized;
  }

  @override
  String get title => '$MemoryOfflineScene';

  Future<void> tapAndSettle(
    WidgetTester tester,
    Finder finder, {
    Duration? pause,
  }) async {
    await tester.tap(finder);
    if (pause != null) {
      await tester.runAsync(() => Future.delayed(pause));
    }
    await tester.pumpAndSettle();
  }

  void tearDown() {}
}
