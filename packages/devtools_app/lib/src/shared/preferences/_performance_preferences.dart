// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'preferences.dart';

class PerformancePreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  final showFlutterFramesChart = ValueNotifier<bool>(true);

  static final _showFlutterFramesChartId =
      '${gac.performance}.${gac.PerformanceEvents.framesChartVisibility.name}';

  Future<void> init() async {
    addAutoDisposeListener(
      showFlutterFramesChart,
      () {
        storage.setValue(
          _showFlutterFramesChartId,
          showFlutterFramesChart.value.toString(),
        );
        ga.select(
          gac.performance,
          gac.PerformanceEvents.framesChartVisibility.name,
          value: showFlutterFramesChart.value ? 1 : 0,
        );
      },
    );
    showFlutterFramesChart.value =
        await storage.getValue(_showFlutterFramesChartId) != 'false';
  }
}
