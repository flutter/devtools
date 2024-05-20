// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';

import '../../../../../shared/primitives/simple_items.dart';
import '../../../shared/primitives/memory_timeline.dart';
import '../data/primitives.dart';

@visibleForTesting
enum Json {
  isDeviceAndroid,
  timeline,
  interval,
  isLegendVisible;
}

/// Chart data, that should be saved when transferred to offline data mode.
class ChartData {
  ChartData({
    required ControllerCreationMode mode,
    this.isDeviceAndroid,
    MemoryTimeline? timeline,
    ChartInterval? interval,
    bool? isLegendVisible,
  })  : assert(
          mode == ControllerCreationMode.connected ||
              (mode == ControllerCreationMode.offlineData &&
                  isDeviceAndroid != null &&
                  timeline != null &&
                  interval != null &&
                  isLegendVisible != null),
        ),
        _displayInterval =
            ValueNotifier<ChartInterval>(interval ?? ChartInterval.theDefault),
        _isLegendVisible = ValueNotifier<bool>(isLegendVisible ?? true) {
    this.timeline = timeline ?? MemoryTimeline();
  }

  factory ChartData.fromJson(Map<String, dynamic> json) {
    final result = ChartData(
      mode: ControllerCreationMode.offlineData,
      isDeviceAndroid: json[Json.isDeviceAndroid.name] as bool? ?? false,
      timeline: deserialize<MemoryTimeline>(
        json[Json.timeline.name],
        MemoryTimeline.fromJson,
      ),
      interval: ChartInterval.byName(json[Json.interval.name]) ??
          ChartInterval.theDefault,
      isLegendVisible: json[Json.isLegendVisible.name] as bool?,
    );
    return result;
  }

  Map<String, dynamic> toJson() {
    return {
      Json.isDeviceAndroid.name: isDeviceAndroid ?? false,
      Json.timeline.name: timeline,
      Json.interval.name: displayInterval.name,
      Json.isLegendVisible.name: isLegendVisible.value,
    };
  }

  /// Whether the device is an Android device.
  ///
  /// If connected to application, this value is set after the class creation,
  /// by the instance owner.
  bool? isDeviceAndroid;

  late final MemoryTimeline timeline;

  /// Default is to display default tick width based on width of chart of the collected
  /// data in the chart.
  ChartInterval get displayInterval => _displayInterval.value;
  final ValueNotifier<ChartInterval> _displayInterval;
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
