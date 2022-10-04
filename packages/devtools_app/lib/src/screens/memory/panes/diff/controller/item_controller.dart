// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../../../../primitives/auto_dispose.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/heap/model.dart';
import 'heap_diff.dart';

typedef RetainingPathRecord = MapEntry<ClassOnlyHeapPath, SizeOfClassSet>;

abstract class DiffListItem extends DisposableController {
  /// Number, that if shown in name, should be unique in the list.
  ///
  /// If the number is not expected to be shown in UI, it should be 0.
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
  SnapshotListItem({
    required Future<AdaptedHeapData?> receiver,
    required this.id,
    required this.displayNumber,
    required this.isolateName,
    required this.diffStore,
    required this.selectedClassName,
  }) {
    _isProcessing.value = true;
    receiver.whenComplete(() async {
      final data = await receiver;
      if (data != null) {
        heap = AdaptedHeap(data);
        updateSelectedRecord();
        // TODO(https://github.com/flutter/devtools/issues/4539): it is unclear
        // whether preserving the selection between snapshots should be the
        // default behavior. Revisit after consulting with UXR.
        addAutoDisposeListener(selectedClassName, () => updateSelectedRecord());
      }
      _isProcessing.value = false;
    });
  }

  final int id;

  final String isolateName;

  final HeapDiffStore diffStore;

  AdaptedHeap? heap;

  @override
  final int displayNumber;

  String get name => '$isolateName-$displayNumber';

  ValueListenable<SnapshotListItem?> get diffWith => _diffWith;
  final _diffWith = ValueNotifier<SnapshotListItem?>(null);
  void setDiffWith(SnapshotListItem? value) {
    _diffWith.value = value;
    updateSelectedRecord();
  }

  final ValueNotifier<String?> selectedClassName;

  final selectedClassStats = ValueNotifier<HeapClassStatistics?>(null);

  List<RetainingPathRecord> get retainingPathList {
    final classStats = selectedClassStats.value;
    if (classStats == null) return [];
    return _retainingPathForClass.putIfAbsent(
      classStats,
      () => classStats.sizeByRetainingPath.entries.toList(growable: false),
    );
  }

  final _retainingPathForClass =
      <HeapClassStatistics, List<RetainingPathRecord>>{};

  @override
  bool get hasData => heap != null;

  HeapStatistics get statsToShow {
    final theHeap = heap!;
    final itemToDiffWith = diffWith.value;
    if (itemToDiffWith == null) return theHeap.stats;
    return diffStore.compare(theHeap, itemToDiffWith.heap!).stats;
  }

  void updateSelectedRecord() {
    if (selectedClassName.value == null) {
      selectedClassStats.value = null;
      return;
    }
    final classStats = statsToShow.statsByClassName[selectedClassName.value];
    if (classStats != null) {
      _retainingPathForClass[classStats] =
          classStats.sizeByRetainingPath.entries.toList(growable: false);
    }
    selectedClassStats.value = classStats;
  }
}
