// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/primitives/feature_flags.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:stager/stager.dart';

import '../load_offline_snapshot.dart';

/// To run:
/// flutter run -t test/scenes/performance/default.stager_app.dart -d macos
class PerformanceDefaultScene extends Scene {
  late PerformanceController controller;
  final screen = const PerformanceScreen();

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

    await ensureInspectorDependencies();
    setGlobal(OfflineModeController, OfflineModeController());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(ServiceConnectionManager, ServiceConnectionManager());
    await loadOfflineSnapshot(
      'test/test_data/performance/performance_diagnosis_world_clock.json',
    );

    controller = PerformanceController();
  }

  @override
  String get title => '$PerformanceDefaultScene';

  void tearDown() {
    FeatureFlags.widgetRebuildstats = false;
  }
}
