// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../../../../shared/primitives/simple_items.dart';
import '../../../shared/primitives/memory_timeline.dart';
import '../data/primitives.dart';

/// Chart data, that should be saved when transferred to offline data mode.
class ChartData {
  ChartData._({
    this.isDeviceAndroid,
    MemoryTimeline? timeline,
    ChartInterval? interval,
    bool? isLegendVisible,
  }) {
    this.timeline = timeline ?? MemoryTimeline();
    _displayInterval =
        ValueNotifier<ChartInterval>(interval ?? ChartInterval.theDefault);
    _isLegendVisible = ValueNotifier<bool>(isLegendVisible ?? true);
  }

  ChartData.connected() : this._();

  ChartData.offlineData(
    ChartData data,
  ) : this._(isDeviceAndroid: data.isDeviceAndroid!);

  /// Wether device is android, if [mode] is not [DevToolsMode.connected].
  ///
  /// If [mode] is [DevToolsMode.connected], this value is null
  /// and chart visibility should be detected based on signal from connected app.
  final bool? isDeviceAndroid;

  late final MemoryTimeline timeline;

  /// Default is to display default tick width based on width of chart of the collected
  /// data in the chart.
  ChartInterval get displayInterval => _displayInterval.value;
  late final ValueNotifier<ChartInterval> _displayInterval;
  set displayInterval(ChartInterval interval) {
    _displayInterval.value = interval;
  }

  ValueListenable<bool> get isLegendVisible => _isLegendVisible;
  late final ValueNotifier<bool> _isLegendVisible;
  bool toggleLegendVisibility() =>
      _isLegendVisible.value = !_isLegendVisible.value;

  void dispose() {
    _displayInterval.dispose();
    _isLegendVisible.dispose();
  }
}
