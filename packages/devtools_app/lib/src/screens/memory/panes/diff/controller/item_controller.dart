// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../../../shared/memory/adapted_heap_data.dart';
import '../../../../../shared/memory/new/heap_data.dart';
import '../../../../../shared/memory/new/heap_graph_loader.dart';
import '../../../shared/heap/heap.dart';

abstract class SnapshotItem extends DisposableController {
  /// Number to show with auto-generated names that may be non unique, like isolate name.
  int? get displayNumber;

  ValueListenable<bool> get isProcessing => _isProcessing;
  final _isProcessing = ValueNotifier<bool>(false);

  /// If true, the item contains data, that can be compared and analyzed.
  bool get hasData;

  @override
  void dispose() {
    _isProcessing.dispose();
    super.dispose();
  }
}

class SnapshotDocItem extends SnapshotItem {
  @override
  int? get displayNumber => null;

  @override
  bool get hasData => false;
}

class SnapshotDataItem extends SnapshotItem implements RenamableItem {
  SnapshotDataItem({
    this.displayNumber,
    required this.defaultName,
  }) {
    _isProcessing.value = true;
  }

  HeapData? get heap => _heap;
  HeapData? _heap;

  /// Automatically assigned name like isolate name or file name.
  final String defaultName;

  @override
  final int? displayNumber;

  @override
  bool get hasData => _heap != null;

  Future<void> loadHeap(HeapGraphLoader loader) async {
    assert(_heap == null);
    final graph = await loader.load();
    if (graph != null) {
      _heap = await calculateHeapData(graph);
    }
    _isProcessing.value = false;
  }

  @override
  String? nameOverride;

  final diffWith = ValueNotifier<SnapshotDataItem?>(null);

  @override
  String get name =>
      nameOverride ??
      '$defaultName${displayNumber == null ? '' : '-$displayNumber'}';

  // TODO: implement totalSize
  int? get totalSize => 0;
}

abstract class RenamableItem {
  String get name;

  String? nameOverride;
}

class SnapshotInstanceItem extends SnapshotItem implements RenamableItem {
  SnapshotInstanceItem({
    this.displayNumber,
    required this.defaultName,
  }) {
    _isProcessing.value = true;
  }

  /// Automatically assigned name like isolate name or file name.
  final String defaultName;

  AdaptedHeap? heap_;

  /// This method is expected to be called once when heap is actually received.
  Future<void> initializeHeapData(AdaptedHeapData? data) async {
    assert(heap_ == null);
    if (data != null) {
      data.snapshotName = name;
      heap_ = await AdaptedHeap.create(data);
    }
    _isProcessing.value = false;
  }

  @override
  final int? displayNumber;

  @override
  String get name =>
      nameOverride ??
      '$defaultName${displayNumber == null ? '' : '-$displayNumber'}';

  @override
  String? nameOverride;

  final diffWith = ValueNotifier<SnapshotInstanceItem?>(null);

  @override
  bool get hasData => heap_ != null;

  int? get totalSize => heap_?.data.totalReachableSize;
}
