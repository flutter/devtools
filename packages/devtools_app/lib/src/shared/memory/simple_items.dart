// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Direction of reference between objects in memory.
enum RefDirection {
  inbound,
  outbound,
}

/// Result of invocation of [identityHashCode].
typedef IdentityHashCode = int;

class MemoryFootprint {
  MemoryFootprint({
    required this.rss,
    required this.dart,
    required this.reachable,
  });

  /// Total memory used by the Dart VM, including shared pages.
  ///
  /// See https://developer.android.com/topic/performance/memory-management.
  final int? rss;

  /// Subset of [rss].
  final int dart;

  /// Subset of [dart].
  final int reachable;
}
