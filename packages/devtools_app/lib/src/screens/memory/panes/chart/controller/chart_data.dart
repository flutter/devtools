// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../../../../shared/primitives/simple_items.dart';
import '../../../shared/primitives/memory_timeline.dart';
import '../data/primitives.dart';

/// Chart data, that should be saved when transferred to offline data mode.
class ChartData {
  ChartData({required this.isDeviceAndroid});

  /// Wether device is android, if [mode] is not [DevToolsMode.connected].
  ///
  /// If [mode] is [DevToolsMode.connected], this value is null
  /// and chart visibility should be detected based on connected app.
  final bool? isDeviceAndroid;

  final MemoryTimeline timeline = MemoryTimeline();

  /// Default is to display default tick width based on width of chart of the collected
  /// data in the chart.
  ChartInterval get displayInterval => _displayInterval.value;
  final _displayInterval =
      ValueNotifier<ChartInterval>(ChartInterval.theDefault);
  set displayInterval(ChartInterval interval) {
    _displayInterval.value = interval;
  }

  ValueListenable<bool> get isLegendVisible => _legendVisibleNotifier;
  final _legendVisibleNotifier = ValueNotifier<bool>(true);
  bool toggleLegendVisibility() =>
      _legendVisibleNotifier.value = !_legendVisibleNotifier.value;

  void dispose() {
    _displayInterval.dispose();
    _legendVisibleNotifier.dispose();
  }
}
