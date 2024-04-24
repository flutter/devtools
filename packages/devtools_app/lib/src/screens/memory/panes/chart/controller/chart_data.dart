// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../../../../../devtools_app.dart';
import '../../../shared/primitives/memory_timeline.dart';
import '../data/primitives.dart';

class _Json {
  static const isDeviceAndroid = 'isAndroid';
  static const timeline = 'timeline';
  static const interval = 'interval';
  static const isLegendVisible = 'isLegendVisible';
}

/// Chart data, that should be saved when transferred to offline data mode.
class ChartData {
  ChartData({
    required DevToolsMode mode,
    this.isDeviceAndroid,
    MemoryTimeline? timeline,
    ChartInterval? interval,
    bool? isLegendVisible,
  }) : assert(
          mode == DevToolsMode.connected ||
              (mode == DevToolsMode.offlineData &&
                  isDeviceAndroid != null &&
                  timeline != null &&
                  interval != null &&
                  isLegendVisible != null),
        ) {
    this.timeline = timeline ?? MemoryTimeline();
    _displayInterval =
        ValueNotifier<ChartInterval>(interval ?? ChartInterval.theDefault);
    _isLegendVisible = ValueNotifier<bool>(isLegendVisible ?? true);
  }

  factory ChartData.fromJson(Map<String, dynamic> json) {
    return ChartData(
      mode: DevToolsMode.offlineData,
      isDeviceAndroid: json[_Json.isDeviceAndroid] as bool? ?? false,
      timeline:
          MemoryTimeline.fromJson(json[_Json.timeline] as Map<String, dynamic>),
      interval: ChartInterval.values
              .firstWhereOrNull((i) => i.name == json[_Json.interval]) ??
          ChartInterval.theDefault,
      isLegendVisible: json[_Json.isLegendVisible] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      _Json.isDeviceAndroid: isDeviceAndroid,
      _Json.timeline: timeline.toJson(),
      _Json.interval: displayInterval.name,
      _Json.isLegendVisible: isLegendVisible.value,
    };
  }

  /// Wether device is android.
  ///
  /// If connected to application, this value is set after the class creation,
  /// by the instance owner.
  bool? isDeviceAndroid;

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
