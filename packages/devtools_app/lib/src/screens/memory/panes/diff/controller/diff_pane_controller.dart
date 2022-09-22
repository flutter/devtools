// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../../../../primitives/utils.dart';
import '../../../primitives/memory_utils.dart';
import '../../../shared/heap/model.dart';
import 'heap_diff.dart';
import 'item_controller.dart';

class DiffPaneController {
  DiffPaneController(this.snapshotTaker);

  final SnapshotTaker snapshotTaker;

  final diffStore = HeapDiffStore();

  /// The list contains one item that show information and all others
  /// are snapshots.
  ValueListenable<List<DiffListItem>> get snapshots => _snapshots;
  final _snapshots = ListValueNotifier(<DiffListItem>[InformationListItem()]);

  ValueListenable<int> get selectedIndex => _selectedIndex;
  final _selectedIndex = ValueNotifier<int>(0);

  /// If true, some process is going on.
  ValueListenable<bool> get isProcessing => _isProcessing;
  final _isProcessing = ValueNotifier<bool>(false);

  DiffListItem get selectedItem => snapshots.value[selectedIndex.value];

  /// Full name for the selected class.
  ValueListenable<String?> get selectedClass => _selectedClass;
  final _selectedClass = ValueNotifier<String?>(null);
  void setSelectedClass(String? value) => _selectedClass.value = value;

  /// True, if the list contains snapshots, i.e. items beyond the first
  /// informational item.
  bool get hasSnapshots => snapshots.value.length > 1;

  Future<void> takeSnapshot() async {
    _isProcessing.value = true;
    final future = snapshotTaker.take();
    _snapshots.add(
      SnapshotListItem(
        future,
        _nextDisplayNumber(),
        currentIsolateName ?? '<isolate-not-detected>',
        diffStore,
        selectedClass,
      ),
    );
    await future;
    final newElementIndex = snapshots.value.length - 1;
    _selectedIndex.value = newElementIndex;
    _isProcessing.value = false;
  }

  Future<void> clearSnapshots() async {
    for (var i = 1; i < snapshots.value.length; i++) {
      snapshots.value[i].dispose();
    }
    _snapshots.removeRange(1, snapshots.value.length);
    _selectedIndex.value = 0;
  }

  int _nextDisplayNumber() {
    final numbers = snapshots.value.map((e) => e.displayNumber);
    assert(numbers.isNotEmpty);
    return numbers.max + 1;
  }

  void deleteCurrentSnapshot() {
    assert(selectedItem is SnapshotListItem);
    selectedItem.dispose();
    _snapshots.removeRange(selectedIndex.value, selectedIndex.value + 1);
    // We must change the selectedIndex, because otherwise the content will
    // not be re-rendered.
    _selectedIndex.value = max(selectedIndex.value - 1, 0);
  }

  void select(int index) {
    _selectedIndex.value = index;
  }
}
