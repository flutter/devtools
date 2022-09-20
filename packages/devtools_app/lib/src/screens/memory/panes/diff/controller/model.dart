// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../../../../primitives/utils.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/heap/heap_analyzer.dart';
import '../../../shared/heap/model.dart';

abstract class DiffListItem {
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

class SnapshotListItem extends DiffListItem {
  SnapshotListItem(
    Future<AdaptedHeapData?> receiver,
    this.displayNumber,
    this._isolateName,
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

  AdaptedHeap? heap;

  @override
  final int displayNumber;

  String get name => '$_isolateName-$displayNumber';

  var sorting = ColumnSorting();
}

class ColumnSorting {
  bool initialized = false;
  SortDirection direction = SortDirection.ascending;
  int columnIndex = 0;
}
