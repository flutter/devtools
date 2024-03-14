// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file_selector/file_selector.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../shared/analytics/analytics.dart' as ga;
import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/analytics/metrics.dart';
import '../../../../shared/memory/adapted_heap_data.dart';
import '../primitives/memory_timeline.dart';
import '../primitives/memory_utils.dart';

abstract class SnapshotTaker {
  Future<AdaptedHeapData?> take();
}

/// This class is needed to make the snapshot taking operation mockable.
class SnapshotTakerRuntime extends SnapshotTaker {
  SnapshotTakerRuntime(this._timeline);

  final MemoryTimeline? _timeline;

  @override
  Future<AdaptedHeapData?> take() async {
    final snapshot = await snapshotMemoryInSelectedIsolate();
    _timeline?.addSnapshotEvent();
    if (snapshot == null) return null;
    final result = await _adaptSnapshotGaWrapper(snapshot);
    return result;
  }
}

class SnapshotTakerFromFile implements SnapshotTaker {
  SnapshotTakerFromFile(this._file);

  final XFile _file;

  @override
  Future<AdaptedHeapData?> take() async {
    final bytes = await _file.readAsBytes();
    return AdaptedHeapData.fromBytes(bytes);
  }
}

Future<AdaptedHeapData> _adaptSnapshotGaWrapper(HeapSnapshotGraph graph) async {
  late final AdaptedHeapData result;
  await ga.timeAsync(
    gac.memory,
    gac.MemoryTime.adaptSnapshot,
    asyncOperation: () async =>
        result = await AdaptedHeapData.fromHeapSnapshot(graph),
    screenMetricsProvider: () => MemoryScreenMetrics(
      heapObjectsTotal: graph.objects.length,
    ),
  );
  return result;
}
