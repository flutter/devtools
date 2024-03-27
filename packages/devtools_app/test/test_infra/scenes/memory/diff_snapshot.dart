// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/controller/diff_pane_controller.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/diff_pane.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/class_filter.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stager/stager.dart';

import '../../test_data/memory/heap/heap_data.dart';

/// Fragment of the memory screen with diff for two snapshots.
///
/// To run:
/// flutter run -t test/test_infra/scenes/memory/diff_snapshot.stager_app.g.dart -d macos
class DiffSnapshotScene extends Scene {
  late DiffPaneController diffController;
  late FakeServiceConnectionManager fakeServiceConnection;

  @override
  Widget build(BuildContext context) {
    return wrap(
      SnapshotInstanceItemPane(controller: diffController),
    );
  }

  @override
  Future<void> setUp() async {
    setGlobal(OfflineModeController, OfflineModeController());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());

    fakeServiceConnection = FakeServiceConnectionManager();
    mockConnectedApp(
      fakeServiceConnection.serviceManager.connectedApp!,
      isFlutterApp: true,
      isProfileBuild: true,
      isWebApp: false,
    );
    setGlobal(ServiceConnectionManager, fakeServiceConnection);

    diffController = DiffPaneController(HeapGraphLoaderGoldens());
    setClassFilterToShowAll();

    await diffController.takeSnapshot();
    await diffController.takeSnapshot();
  }

  @override
  String get title => '$DiffSnapshotScene';

  void setClassFilterToShowAll() {
    diffController.derived.applyFilter(
      ClassFilter(filterType: ClassFilterType.showAll, except: '', only: ''),
    );
  }

  void tearDown() {}
}
