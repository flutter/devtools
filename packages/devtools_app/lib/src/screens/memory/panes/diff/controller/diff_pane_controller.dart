// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../../../../primitives/auto_dispose.dart';
import '../../../../../primitives/utils.dart';
import '../../../primitives/memory_utils.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/heap/model.dart';
import 'heap_diff.dart';
import 'item_controller.dart';

class DiffPaneController extends DisposableController {
  DiffPaneController(this.snapshotTaker);

  final SnapshotTaker snapshotTaker;

  /// If true, some process is going on.
  ValueListenable<bool> get isProcessing => _isProcessing;
  final _isProcessing = ValueNotifier<bool>(false);

  late final data = DiffData();

  void setClassFilter(String value) {
    data.core._classFilter.value = value;

    // TODO(polina-c): filter the data before opening the feature:
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
  bool get hasSnapshots => data.core.snapshots.value.length > 1;

  SnapshotItem get selectedSnapshotItem =>
      data.core._snapshots.value[data.core.snapshotIndex.value];

  // This value should never be reset. It is incremented for every snapshot that
  // is taken, and is used to assign a unique id to each [SnapshotListItem].
  int _snapshotId = 0;

  Future<void> takeSnapshot() async {
    _isProcessing.value = true;
    final future = snapshotTaker.take();
    final snapshots = data.core._snapshots;
    snapshots.add(
      SnapshotInstanceItem(
        receiver: future,
        id: _snapshotId++,
        displayNumber: _nextDisplayNumber(),
        isolateName: currentIsolateName ?? '<isolate-not-detected>',
      ),
    );
    await future;
    final newElementIndex = snapshots.value.length - 1;
    data.core._snapshotIndex.value = newElementIndex;
    _isProcessing.value = false;
  }

  Future<void> clearSnapshots() async {
    final snapshots = data.core._snapshots;
    for (var i = 1; i < snapshots.value.length; i++) {
      snapshots.value[i].dispose();
    }
    snapshots.removeRange(1, snapshots.value.length);
    data.core._snapshotIndex.value = 0;
  }

  int _nextDisplayNumber() {
    final numbers = data.core._snapshots.value.map((e) => e.displayNumber);
    assert(numbers.isNotEmpty);
    return numbers.max + 1;
  }

  void deleteCurrentSnapshot() {
    assert(selectedSnapshotItem is SnapshotInstanceItem);
    selectedSnapshotItem.dispose();
    final index = data.core.snapshotIndex.value;
    data.core._snapshots.removeRange(
      index,
      index + 1,
    );
    // We must change the selectedIndex, because otherwise the content will
    // not be re-rendered.
    data.core._snapshotIndex.value = max(index - 1, 0);
  }
}

/// Values that define what data to show on diff screen.
class CoreData {
  /// The list contains one item that show information and all others
  /// are snapshots.
  ValueListenable<List<SnapshotItem>> get snapshots => _snapshots;
  final _snapshots = ListValueNotifier(<SnapshotItem>[SnapshotDocItem()]);

  /// Selected snapshot.
  ValueListenable<int> get snapshotIndex => _snapshotIndex;
  final _snapshotIndex = ValueNotifier<int>(0);
  void setSnapshotIndex(int value) => _snapshotIndex.value = value;

  // TODO(https://github.com/flutter/devtools/issues/4539): it is unclear
  // whether preserving the selection between snapshots should be the
  // default behavior. Revisit after consulting with UXR.

  /// Full name for the selected class (cross-snapshot).
  HeapClassName? className;

  /// Selected retaining path (cross-snapshot).
  ClassOnlyHeapPath? path;

  ValueListenable<String?> get classFilter => _classFilter;
  final _classFilter = ValueNotifier<String?>(null);
}

/// Values that can be calculated from [CoreData].
class DerivedData {
  /// Classes to show.
  final heapClasses = ValueNotifier<HeapClasses?>(null);

  /// Selected single class item in snapshot, to provide to table widget.
  final singleClassStats = ValueNotifier<SingleClassStats?>(null);

  /// Selected diff class item in snapshot, to provide to table widget.
  final diffClassStats = ValueNotifier<DiffClassStats?>(null);

  /// List of retaining paths to show for the selected class.
  final pathEntries = ValueNotifier<List<StatsByPathEntry>?>(null);

  /// Selected retaining path record in a concrete snapshot, to provide to table widget.
  final pathEntry = ValueNotifier<StatsByPathEntry?>(null);

  final diffStore = HeapDiffStore();
}

class DiffData extends DisposableController with AutoDisposeControllerMixin {
  DiffData() {
    addAutoDisposeListener(
      derived.singleClassStats,
      () => _setClassIfNotNull(derived.singleClassStats.value?.heapClass),
    );
    addAutoDisposeListener(
      derived.diffClassStats,
      () => _setClassIfNotNull(derived.diffClassStats.value?.heapClass),
    );
    addAutoDisposeListener(
      derived.pathEntry,
      () => _setPathIfNotNull(derived.pathEntry.value?.key),
    );
    addAutoDisposeListener(
      core.snapshotIndex,
      _recalculateValues,
    );
    addAutoDisposeListener(
      core._snapshots,
      _recalculateValues,
    );
  }

  final core = CoreData();

  final derived = DerivedData();

  /// Updates cross-snapshot class if the argument is not null.
  void _setClassIfNotNull(HeapClassName? theClass) {
    if (theClass == null || theClass == core.className) return;
    core.className = theClass;
    _recalculateValues();
  }

  /// Updates cross-snapshot path if the argument is not null.
  void _setPathIfNotNull(ClassOnlyHeapPath? path) {
    if (path == null || path == core.path) return;
    core.path = path;
    _recalculateValues();
  }

  void _assertIntegrity() {
    assert(() {
      final singleClass = derived.singleClassStats.value;
      final diffClass = derived.diffClassStats.value;
      final theClass = singleClass?.heapClass ?? diffClass?.heapClass;

      assert(singleClass == null || diffClass == null);
      assert(theClass == null || theClass == core.className);

      return true;
    }());
  }

  /// List of classes to show for the selected snapshot.
  HeapClasses? _snapshotClasses() {
    final theItem = core._snapshots.value[core.snapshotIndex.value];
    if (theItem is! SnapshotInstanceItem) return null;
    final heap = theItem.heap;
    if (heap == null) return null;
    final itemToDiffWith = theItem.diffWith.value;
    if (itemToDiffWith == null) return heap.classes;
    return derived.diffStore.compare(heap, itemToDiffWith.heap!);
  }

  /// Set [derived] values based on [core] values.
  void _recalculateValues() {
    final classes = _snapshotClasses();
    derived.heapClasses.value = classes;

    // Set classes to show.
    final singleClass = derived.singleClassStats;
    final diffClass = derived.diffClassStats;
    if (classes is SingleHeapClasses) {
      singleClass.value = classes.classesByName[core.className];
      diffClass.value = null;
    } else if (classes is DiffHeapClasses) {
      singleClass.value = null;
      diffClass.value = classes.classesByName[core.className];
    } else if (classes == null) {
      singleClass.value = null;
      diffClass.value = null;
    } else {
      throw StateError('Unexpected type: ${classes.runtimeType}.');
    }

    // Set pathes to show.
    final theClass = singleClass.value ?? diffClass.value;
    final pathEntries =
        derived.pathEntries.value = theClass?.statsByPathEntries;
    final pathes = theClass?.statsByPath;
    StatsByPathEntry? byPathEntry;
    if (core.path != null && pathes != null && pathEntries != null) {
      final pathStats = pathes[core.path];
      if (pathStats != null) {
        byPathEntry = pathEntries.firstWhereOrNull((e) => e.key == core.path);
      }
    }
    derived.pathEntry.value = byPathEntry;

    _assertIntegrity();
  }
}
