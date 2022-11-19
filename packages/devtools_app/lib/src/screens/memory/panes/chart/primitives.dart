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
  theDefault,
  oneMinute,
  fiveMinutes,
  tenMinutes,
  all,
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
  chartDuration(ChartInterval.oneMinute)!.inMinutes.toString(),
  chartDuration(ChartInterval.fiveMinutes)!.inMinutes.toString(),
  chartDuration(ChartInterval.tenMinutes)!.inMinutes.toString(),
  displayAll,
];

String displayDuration(ChartInterval interval) =>
    displayDurationsStrings[interval.index];

ChartInterval chartInterval(String displayName) {
  final index = displayDurationsStrings.indexOf(displayName);
  switch (index) {
    case 0:
      assert(index == ChartInterval.theDefault.index);
      return ChartInterval.theDefault;
    case 1:
      assert(index == ChartInterval.oneMinute.index);
      return ChartInterval.oneMinute;
    case 2:
      assert(index == ChartInterval.fiveMinutes.index);
      return ChartInterval.fiveMinutes;
    case 3:
      assert(index == ChartInterval.tenMinutes.index);
      return ChartInterval.tenMinutes;
    case 4:
      assert(index == ChartInterval.all.index);
      return ChartInterval.all;
    default:
      return ChartInterval.all;
  }
}
