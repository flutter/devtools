// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'model.dart';
import 'spanning_tree.dart';

class AdaptedHeap {
  AdaptedHeap(this.data);

  final AdaptedHeapData data;

  late final stats = _heapStats();

  List<HeapStatsRecord> _heapStats() {
    final result = <String, HeapStatsRecord>{};
    if (!data.isSpanningTreeBuilt) buildSpanningTree(data);
    for (var object in data.objects) {
      // We do not show objects that will be garbage collected soon.
      if (object.retainedSize == null || object.heapClass.isSentinel) continue;

      if (!result.containsKey(object.heapClass.fullName)) {
        result[object.heapClass.fullName] = HeapStatsRecord(object.heapClass);
      }
      final stats = result[object.heapClass.fullName]!;
      stats.retainedSize += object.retainedSize ?? 0;
      stats.shallowSize += object.shallowSize;
      stats.instanceCount++;
    }
    return result.values.toList();
  }
}
