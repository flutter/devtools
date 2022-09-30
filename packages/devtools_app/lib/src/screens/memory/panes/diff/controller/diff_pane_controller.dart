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
  ValueListenable<List<SnapshotItem>> get snapshots => _snapshots;
  final _snapshots = ListValueNotifier(<SnapshotItem>[SnapshotDocItem()]);

  ValueListenable<int> get selectedSnapshotIndex => _selectedSnapshotIndex;
  final _selectedSnapshotIndex = ValueNotifier<int>(0);
  void setSelectedSnapshotIndex(int index) =>
      _selectedSnapshotIndex.value = index;

  /// If true, some process is going on.
  ValueListenable<bool> get isProcessing => _isProcessing;
  final _isProcessing = ValueNotifier<bool>(false);

  SnapshotItem get selectedSnapshotItem =>
      snapshots.value[selectedSnapshotIndex.value];

  /// Full name for the selected class.
  ValueListenable<HeapClassName?> get selectedClass => _selectedClass;
  final _selectedClass = ValueNotifier<HeapClassName?>(null);
  void setSelectedClass(HeapClassName? value) => _selectedClass.value = value;

  /// Selected retaining path.
  ValueListenable<ClassOnlyHeapPath?> get selectedPath => _selectedPath;
  final _selectedPath = ValueNotifier<ClassOnlyHeapPath?>(null);
  void setselectedPath(ClassOnlyHeapPath? value) => _selectedPath.value = value;

  ValueListenable<String?> get classFilter => _classFilter;
  final _classFilter = ValueNotifier<String?>(null);
  void setClassFilter(String value) {
    _classFilter.value = value;
    throw UnimplementedError();
    // if (value.isEmpty && _currentFilter.isEmpty) return;
    // final updatedFilteredClassList = (value.contains(_currentFilter)
    //     ? _filteredClassList.value
    //     : _unfilteredClassList)
    //     .where(
    //       (e) => e.cls.name!.contains(value),
    // )
    //     .map((e) => _tracedClasses[e.cls.id!]!)
    //     .toList();
    //
    // _filteredClassList.replaceAll(updatedFilteredClassList);
    // _currentFilter = value;
  }

  /// True, if the list contains snapshots, i.e. items beyond the first
  /// informational item.
  bool get hasSnapshots => snapshots.value.length > 1;

  // This value should never be reset. It is incremented for every snapshot that
  // is taken, and is used to assign a unique id to each [SnapshotListItem].
  int _snapshotId = 0;

  Future<void> takeSnapshot() async {
    _isProcessing.value = true;
    final future = snapshotTaker.take();
    _snapshots.add(
      SnapshotInstanceItem(
        receiver: future,
        id: _snapshotId++,
        displayNumber: _nextDisplayNumber(),
        isolateName: currentIsolateName ?? '<isolate-not-detected>',
        diffStore: diffStore,
        selectedClass: selectedClass,
        selectedPath: selectedPath,
      ),
    );
    await future;
    final newElementIndex = snapshots.value.length - 1;
    _selectedSnapshotIndex.value = newElementIndex;
    _isProcessing.value = false;
  }

  Future<void> clearSnapshots() async {
    for (var i = 1; i < snapshots.value.length; i++) {
      snapshots.value[i].dispose();
    }
    _snapshots.removeRange(1, snapshots.value.length);
    _selectedSnapshotIndex.value = 0;
  }

  int _nextDisplayNumber() {
    final numbers = snapshots.value.map((e) => e.displayNumber);
    assert(numbers.isNotEmpty);
    return numbers.max + 1;
  }

  void deleteCurrentSnapshot() {
    assert(selectedSnapshotItem is SnapshotInstanceItem);
    selectedSnapshotItem.dispose();
    _snapshots.removeRange(
      selectedSnapshotIndex.value,
      selectedSnapshotIndex.value + 1,
    );
    // We must change the selectedIndex, because otherwise the content will
    // not be re-rendered.
    _selectedSnapshotIndex.value = max(selectedSnapshotIndex.value - 1, 0);
  }
}
