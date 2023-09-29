// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../../../shared/memory/adapted_heap_data.dart';
import '../../../shared/heap/heap.dart';

abstract class SnapshotItem extends DisposableController {
  /// Number, that if shown in name, should be unique in the list.
  ///
  /// If the number is not expected to be shown in UI, it should be 0.
  int get displayNumber;

  ValueListenable<bool> get isProcessing => _isProcessing;
  final _isProcessing = ValueNotifier<bool>(false);

  /// If true, the item contains data, that can be compared and analyzed.
  bool get hasData;
}

class SnapshotDocItem extends SnapshotItem {
  @override
  int get displayNumber => 0;

  @override
  bool get hasData => false;
}

class SnapshotInstanceItem extends SnapshotItem {
  SnapshotInstanceItem({
    required this.displayNumber,
    required this.isolateName,
    required this.id,
  }) {
    _isProcessing.value = true;
  }

  final int id;

  final String isolateName;

  AdaptedHeap? heap;

  /// This method is expected to be called once when heap is actually received.
  Future<void> initializeHeapData(AdaptedHeapData? data) async {
    assert(heap == null);
    if (data != null) {
      data.snapshotName = name;
      heap = await AdaptedHeap.create(data);
    }
    _isProcessing.value = false;
  }

  @override
  final int displayNumber;

  String get name => nameOverride ?? '$isolateName-$displayNumber';

  String? nameOverride;

  final diffWith = ValueNotifier<SnapshotInstanceItem?>(null);

  @override
  bool get hasData => heap != null;

  int? get totalSize => heap?.data.totalReachableSize;
}
