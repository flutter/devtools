// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../../../../primitives/auto_dispose.dart';
import '../../../../../primitives/utils.dart';
import '../../../shared/heap/heap_analysis.dart';
import '../../../shared/heap/model.dart';

abstract class DiffListItem extends DisposableController {
  /// Number, that, if shown in name, should be unique in the list.
  ///
  /// If the number is not shown, it should be 0.
  int get displayNumber;

  ValueListenable<bool> get isProcessing => _isProcessing;
  final _isProcessing = ValueNotifier<bool>(false);
}

class InformationListItem extends DiffListItem {
  @override
  int get displayNumber => 0;
}

class SnapshotListItem extends DiffListItem with AutoDisposeControllerMixin {
  SnapshotListItem(
    Future<AdaptedHeap?> receiver,
    this.displayNumber,
    this._isolateName,
  ) {
    _isProcessing.value = true;
    receiver.whenComplete(() async {
      final heap = await receiver;
      if (heap != null) stats = heapStats(heap);
      _isProcessing.value = false;
    });

    addAutoDisposeListener(diffWith, _handleDiff);
  }

  final String _isolateName;

  List<HeapStatsRecord>? stats;
  List<HeapStatsRecord>? diff;

  @override
  final int displayNumber;

  String get name => '$_isolateName-$displayNumber';

  var sorting = ColumnSorting();

  final diffWith = ValueNotifier<SnapshotListItem?>(null);

  void _handleDiff() {}
}

class ColumnSorting {
  bool initialized = false;
  SortDirection direction = SortDirection.ascending;
  int columnIndex = 0;
}
