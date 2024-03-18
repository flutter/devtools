// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Direction of reference between objects in memory.
enum RefDirection {
  inbound,
  outbound,
}

class MemoryFootprint {
  MemoryFootprint({
    required this.dart,
    required this.reachable,
  });

  /// Reachable and unreachable total dart heap size.
  final int dart;

  /// Subset of [dart].
  final int reachable;
}

/// Value for rootIndex is taken from the doc:
/// https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/heap_snapshot.md#object-ids
const int heapRootIndex = 1;
