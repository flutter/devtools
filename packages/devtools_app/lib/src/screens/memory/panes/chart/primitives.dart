// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

enum ChartType {
  DartHeaps,
  AndroidHeaps,
}

/// Automatic pruning of collected memory statistics (plotted) full data is
/// still retained. Default is the best view each tick is 10 pixels, the
/// width of an event symbol e.g., snapshot, monitor, etc.
enum ChartInterval {
  Default,
  OneMinute,
  FiveMinutes,
  TenMinutes,
  All,
}

/// Duration for each ChartInterval.
const displayDurations = <Duration?>[
  Duration.zero, // ChartInterval.Default
  Duration(minutes: 1), // ChartInterval.OneMinute
  Duration(minutes: 5), // ChartInterval.FiveMinutes
  Duration(minutes: 10), // ChartInterval.TenMinutes
  null, // ChartInterval.All
];

Duration? chartDuration(ChartInterval interval) =>
    displayDurations[interval.index];

const displayDefault = 'Default';
const displayAll = 'All';

final displayDurationsStrings = <String>[
  displayDefault,
  chartDuration(ChartInterval.OneMinute)!.inMinutes.toString(),
  chartDuration(ChartInterval.FiveMinutes)!.inMinutes.toString(),
  chartDuration(ChartInterval.TenMinutes)!.inMinutes.toString(),
  displayAll,
];

String displayDuration(ChartInterval interval) =>
    displayDurationsStrings[interval.index];

ChartInterval chartInterval(String displayName) {
  final index = displayDurationsStrings.indexOf(displayName);
  switch (index) {
    case 0:
      assert(index == ChartInterval.Default.index);
      return ChartInterval.Default;
    case 1:
      assert(index == ChartInterval.OneMinute.index);
      return ChartInterval.OneMinute;
    case 2:
      assert(index == ChartInterval.FiveMinutes.index);
      return ChartInterval.FiveMinutes;
    case 3:
      assert(index == ChartInterval.TenMinutes.index);
      return ChartInterval.TenMinutes;
    case 4:
      assert(index == ChartInterval.All.index);
      return ChartInterval.All;
    default:
      return ChartInterval.All;
  }
}
