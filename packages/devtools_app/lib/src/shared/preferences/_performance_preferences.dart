// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'preferences.dart';

/// Preferences for the Performance screen that are persisted to local storage.
class PerformancePreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  /// Whether the Flutter frames chart should be visible or hidden.
  final showFlutterFramesChart = ValueNotifier<bool>(true);

  /// Whether CPU samples should be included in the Perfetto timeline.
  final includeCpuSamplesInTimeline = ValueNotifier<bool>(false);

  static final _showFlutterFramesChartId =
      '${gac.performance}.${gac.PerformanceEvents.framesChartVisibility.name}';

  static final _includeCpuSamplesInTimelineId =
      '${gac.performance}.${gac.PerformanceEvents.includeCpuSamplesInTimeline.name}';

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
    showFlutterFramesChart.value = await boolValueFromStorage(
      _showFlutterFramesChartId,
      defaultsTo: true,
    );

    addAutoDisposeListener(
      includeCpuSamplesInTimeline,
      () {
        storage.setValue(
          _includeCpuSamplesInTimelineId,
          includeCpuSamplesInTimeline.value.toString(),
        );
        ga.select(
          gac.performance,
          gac.PerformanceEvents.includeCpuSamplesInTimeline.name,
          value: includeCpuSamplesInTimeline.value ? 1 : 0,
        );
      },
    );
    includeCpuSamplesInTimeline.value = await boolValueFromStorage(
      _includeCpuSamplesInTimelineId,
      defaultsTo: false,
    );
  }
}
