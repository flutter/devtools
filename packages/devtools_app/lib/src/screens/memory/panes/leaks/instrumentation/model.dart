// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

enum LeakType {
  /// Not disposed and garbage collected.
  notDisposed,

  /// Disposed and not garbage collected when expected.
  notGCed,

  /// Disposed and garbage collected later than expected.
  gcedLate,
}

LeakType _parseLeakType(String source) =>
    LeakType.values.firstWhere((e) => e.toString() == source);

/// Statistical information about found leaks.
class LeakSummary {
  LeakSummary(this.totals);

  factory LeakSummary.fromJson(Map<String, dynamic> json) => LeakSummary(
        json.map(
          (key, value) => MapEntry(_parseLeakType(key), int.parse(value)),
        ),
      );

  final Map<LeakType, int> totals;

  bool get isEmpty => totals.values.sum == 0;

  String toMessage() {
    return '${totals.values.sum} memory leak(s): '
        'not disposed: ${totals[LeakType.notDisposed]}, '
        'not GCed: ${totals[LeakType.notGCed]}, '
        'GCed late: ${totals[LeakType.gcedLate]}';
  }

  Map<String, dynamic> toJson() =>
      totals.map((key, value) => MapEntry(key.toString(), value.toString()));

  bool matches(LeakSummary? other) =>
      other != null && mapEquals(totals, other.totals);
}
