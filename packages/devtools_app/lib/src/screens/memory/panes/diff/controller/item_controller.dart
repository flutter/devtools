// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../../../../primitives/auto_dispose.dart';
import '../../../shared/heap/class_filter.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/heap/model.dart';

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

  void setHeapData(AdaptedHeapData? data, ValueListenable<ClassFilter> filter) {
    assert(heap == null);
    if (data != null) heap = AdaptedHeap(data, filter);
    _isProcessing.value = false;
  }

  @override
  final int displayNumber;

  String get name => '$isolateName-$displayNumber';

  final diffWith = ValueNotifier<SnapshotInstanceItem?>(null);

  @override
  bool get hasData => heap != null;
}
