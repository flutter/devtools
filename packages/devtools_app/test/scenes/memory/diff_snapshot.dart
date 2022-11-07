// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/primitives/feature_flags.dart';
import 'package:devtools_app/src/screens/memory/memory_controller.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/controller/diff_pane_controller.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/diff_pane.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/model.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stager/stager.dart';

import '../../test_data/memory/heap/heap_data.dart';

/// To run:
/// flutter run -t test/scenes/memory/diff_snapshot.stager_app.dart -d macos
class DiffSnapshotScene extends Scene {
  late DiffPaneController diffController;
  late MemoryController controller;
  late FakeServiceManager fakeServiceManager;

  @override
  Widget build() {
    return Scaffold(
      body: SnapshotInstanceItemPane(controller: diffController),
    );
  }

  @override
  Future<void> setUp() async {
    FeatureFlags.memoryDiffing = true;

    setGlobal(OfflineModeController, OfflineModeController());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());

    fakeServiceManager =
        FakeServiceManager(service: FakeServiceManager.createFakeService());
    mockConnectedApp(
      fakeServiceManager.connectedApp!,
      isFlutterApp: true,
      isProfileBuild: true,
      isWebApp: false,
    );
    setGlobal(ServiceConnectionManager, fakeServiceManager);

    controller = MemoryController(
      diffPaneController: diffController =
          DiffPaneController(_TestSnapshotTaker()),
    );

    await diffController.takeSnapshot();
    await diffController.takeSnapshot();
  }

  @override
  String get title => '$DiffSnapshotScene';

  void tearDown() {
    FeatureFlags.memoryDiffing = false;
  }
}

/// Provides test snapshots.
class _TestSnapshotTaker implements SnapshotTaker {
  bool firstTime = true;
  int _nextIndex = 0;

  @override
  Future<AdaptedHeapData?> take() async {
    // This delay is needed for UI to start showing the progress indicator.
    await Future.delayed(const Duration(milliseconds: 100));
    final result = await goldenHeapTests[_nextIndex].loadHeap();

    _nextIndex = (_nextIndex + 1) % goldenHeapTests.length;

    return result;
  }
}
