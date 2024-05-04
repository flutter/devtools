// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';

enum ChartType {
  dartHeaps,
  androidHeaps,
}

/// Automatic pruning of collected memory statistics (plotted) full data is
/// still retained. Default is the best view each tick is 10 pixels, the
/// width of an event symbol e.g., snapshot, monitor, etc.
enum ChartInterval {
  theDefault(Duration.zero, 'Default'),
  oneMinute(Duration(minutes: 1), '1 Minute'),
  fiveMinutes(Duration(minutes: 5), '5 Minutes'),
  tenMinutes(Duration(minutes: 10), '10 Minutes'),
  all(null, 'All');

  const ChartInterval(this.duration, this.displayName);

  final Duration? duration;

  final String displayName;

  static ChartInterval? byName(String name) {
    return values.firstWhereOrNull((i) => i.name == name);
  }
}

const Duration chartUpdateDelay = Duration(milliseconds: 500);
