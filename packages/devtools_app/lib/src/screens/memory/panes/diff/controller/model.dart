// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../../../../primitives/auto_dispose.dart';
import '../../../../../primitives/utils.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/heap/model.dart';
import 'heap_diff.dart';

abstract class DiffListItem extends DisposableController {
  /// Number, that, if shown in name, should be unique in the list.
  ///
  /// If the number is not shown, it should be 0.
  int get displayNumber;

  ValueListenable<bool> get isProcessing => _isProcessing;
  final _isProcessing = ValueNotifier<bool>(false);

  /// If true, the item contains data, that can be compared and analyzed.
  bool get hasData;
}

class InformationListItem extends DiffListItem {
  @override
  int get displayNumber => 0;

  @override
  bool get hasData => false;
}

class SnapshotListItem extends DiffListItem with AutoDisposeControllerMixin {
  SnapshotListItem(
    Future<AdaptedHeapData?> receiver,
    this.displayNumber,
    this._isolateName,
    this.diffStore,
  ) {
    _isProcessing.value = true;
    receiver.whenComplete(() async {
      final data = await receiver;
      if (data != null) heap = AdaptedHeap(data);
      _isProcessing.value = false;
    });
  }

  final String _isolateName;

  final selectedRecord = ValueNotifier<HeapStatsRecord?>(null);

  final HeapDiffStore diffStore;

  AdaptedHeap? heap;

  @override
  final int displayNumber;

  String get name => '$_isolateName-$displayNumber';

  var sorting = ColumnSorting();

  final diffWith = ValueNotifier<SnapshotListItem?>(null);

  @override
  bool get hasData => heap != null;

  HeapStatistics get statsToShow {
    final theHeap = heap!;
    final itemToDiffWith = diffWith.value;
    if (itemToDiffWith == null) return theHeap.stats;
    return diffStore.compare(theHeap, itemToDiffWith.heap!).stats;
  }
}

class ColumnSorting {
  bool initialized = false;
  SortDirection direction = SortDirection.ascending;
  int columnIndex = 0;
}
