// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/shared/feature_flags.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:stager/stager.dart';

/// To run:
/// flutter run -t test/test_infra/scenes/performance/default.stager_app.dart -d macos
class PerformanceDefaultScene extends Scene {
  late PerformanceController controller;

  @override
  Widget build() {
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
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(ServiceConnectionManager, ServiceConnectionManager());
    await _loadOfflineSnapshot(
      'test/test_infra/test_data/performance/performance_diagnosis_world_clock.json',
    );

    controller = PerformanceController();
  }

  @override
  String get title => '$PerformanceDefaultScene';

  void tearDown() {
    FeatureFlags.widgetRebuildstats = false;
  }
}

Future<void> _loadOfflineSnapshot(String path) async {
  final completer = Completer<bool>();
  final importController = ImportController((screenId) {
    completer.complete(true);
  });

  final data = await File(path).readAsString();
  final jsonFile = DevToolsJsonFile(
    name: path,
    data: jsonDecode(data),
    lastModifiedTime: DateTime.now(),
  );
  importController.importData(jsonFile);
  await completer.future;
}
