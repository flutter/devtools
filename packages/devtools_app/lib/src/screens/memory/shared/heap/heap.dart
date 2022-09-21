// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'model.dart';
import 'spanning_tree.dart';

class AdaptedHeap {
  AdaptedHeap(this.data);

  final AdaptedHeapData data;

  late final HeapStatistics stats = _heapStatistics(data);
}

HeapStatistics _heapStatistics(AdaptedHeapData data) {
  final result = <String, HeapStatsRecord>{};
  if (!data.isSpanningTreeBuilt) buildSpanningTree(data);

  for (var object in data.objects) {
    final heapClass = object.heapClass;

    // We do not show objects that will be garbage collected soon.
    if (object.retainedSize == null || heapClass.isSentinel) continue;

    final fullName = heapClass.fullName;
    if (!result.containsKey(fullName)) {
      result[fullName] = HeapStatsRecord(heapClass);
    }
    final stats = result[fullName]!;
    stats.retainedSize += object.retainedSize ?? 0;
    stats.shallowSize += object.shallowSize;
    stats.instanceCount++;
  }
  return HeapStatistics(result);
}
