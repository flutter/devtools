// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'model.dart';

/// Keeps timeline of GC cycles.
///
/// In the current implementation, an unreachable new-space object can require
/// up to two new-space GC followed by an old-space GC to be reclaimed
/// (to break an intergenerational cycle), and an unreachable old-space object
/// can require up to two old-space GCs to be reclaimed (can be floating
/// garbage captured by the incremental barrier).
class GCTimeLine {
  // TODO(polinach): most likely we will end up just counting the number of old
  // space GC events, when VM team completes the request:
  // https://github.com/dart-lang/sdk/issues/49319.

  int _cyclesPassed = 0;
  static const _cycleLength = 8;
  int _eventsPassed = 0;

  void registerOldGCEvent() {
    _eventsPassed++;
    if (_eventsPassed == _cycleLength) {
      _cyclesPassed++;
      _eventsPassed = 0;
    }
  }

  /// Number of the current GC cycle.
  GCTime get now => _cyclesPassed + 1;
}
