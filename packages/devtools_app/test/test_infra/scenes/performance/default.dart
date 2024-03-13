// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/shared/feature_flags.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/helpers.dart';
import 'package:devtools_test/test_data.dart';
import 'package:flutter/material.dart';
import 'package:stager/stager.dart';

/// To run:
/// flutter run -t test/test_infra/scenes/performance/default.stager_app.g.dart -d macos
class PerformanceDefaultScene extends Scene {
  late PerformanceController controller;

  @override
  Widget build(BuildContext context) {
    return wrapWithControllers(
      const PerformanceScreenBody(),
      performance: controller,
    );
  }

  @override
  Future<void> setUp() async {
    FeatureFlags.widgetRebuildstats = true;

    setGlobal(OfflineModeController, OfflineModeController());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());
    setGlobal(BannerMessagesController, BannerMessagesController());
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(ServiceConnectionManager, ServiceConnectionManager());
    await _loadOfflineSnapshot();

    controller = PerformanceController();
  }

  @override
  String get title => '$PerformanceDefaultScene';

  // TODO(kenz): call tearDown on the scenes that use this scene
  void tearDown() {
    FeatureFlags.widgetRebuildstats = false;
  }
}

Future<void> _loadOfflineSnapshot() async {
  final completer = Completer<bool>();
  final importController = ImportController((screenId) {
    completer.complete(true);
  });
  final jsonFile = DevToolsJsonFile(
    name: 'fake/path/to/perf_data.dart',
    data: samplePerformanceData,
    lastModifiedTime: DateTime.now(),
  );
  importController.importData(jsonFile);
  await completer.future;
}
