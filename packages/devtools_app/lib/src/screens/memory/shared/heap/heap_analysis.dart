// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'model.dart';
import 'spanning_tree.dart';

List<HeapStatsRecord> heapStats(AdaptedHeap? heap) {
  final result = <String, HeapStatsRecord>{};
  if (heap == null) return [];
  if (!heap.isSpanningTreeBuilt) buildSpanningTree(heap);
  for (var object in heap.objects) {
    // We do not show objects that will be garbage collected soon.
    if (object.retainedSize == null || object.isSentinel) continue;

    if (!result.containsKey(object.fullClassName)) {
      result[object.fullClassName] = HeapStatsRecord(
        className: object.className,
        library: object.library,
      );
    }
    final stats = result[object.fullClassName]!;
    stats.retainedSize += object.retainedSize ?? 0;
    stats.shallowSize += object.shallowSize;
    stats.instanceCount++;
  }
  return result.values.toList();
}
