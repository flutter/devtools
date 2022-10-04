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

  final core = CoreData();
  late final derived = DerivedData(core);

  /// True, if the list contains snapshots, i.e. items beyond the first
  /// informational item.
  bool get hasSnapshots => core.snapshots.value.length > 1;

  // This value should never be reset. It is incremented for every snapshot that
  // is taken, and is used to assign a unique id to each [SnapshotListItem].
  int _snapshotId = 0;

  Future<void> takeSnapshot() async {
    _isProcessing.value = true;
    final future = snapshotTaker.take();
    final snapshots = core._snapshots;
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
    core._snapshotIndex.value = newElementIndex;
    _isProcessing.value = false;
    derived._recalculateValues(core);
  }

  Future<void> clearSnapshots() async {
    final snapshots = core._snapshots;
    for (var i = 1; i < snapshots.value.length; i++) {
      snapshots.value[i].dispose();
    }
    snapshots.removeRange(1, snapshots.value.length);
    core._snapshotIndex.value = 0;
    derived._recalculateValues(core);
  }

  int _nextDisplayNumber() {
    final numbers = core._snapshots.value.map((e) => e.displayNumber);
    assert(numbers.isNotEmpty);
    return numbers.max + 1;
  }

  void deleteCurrentSnapshot() {
    final item = core.selectedItem;
    assert(item is SnapshotInstanceItem);
    item.dispose();
    final index = core.snapshotIndex.value;
    core._snapshots.removeRange(
      index,
      index + 1,
    );
    // We must change the selectedIndex, because otherwise the content will
    // not be re-rendered.
    core._snapshotIndex.value = max(index - 1, 0);
    derived._recalculateValues(core);
  }

  void setSnapshotIndex(int index) {
    core._snapshotIndex.value = index;
    derived._recalculateValues(core);
  }

  void setClassFilter(String value) {
    // TODO(polina-c): add implementation
  }
}

/// Values that define what data to show on diff screen.
///
/// Widgets should not update the fields directly, they should use
/// [DiffPaneController] or [DerivedData] for this.
class CoreData {
  /// The list contains one item that show information and all others
  /// are snapshots.
  ValueListenable<List<SnapshotItem>> get snapshots => _snapshots;
  final _snapshots = ListValueNotifier(<SnapshotItem>[SnapshotDocItem()]);

  /// Selected snapshot.
  ValueListenable<int> get snapshotIndex => _snapshotIndex;
  final _snapshotIndex = ValueNotifier<int>(0);

  SnapshotItem get selectedItem => _snapshots.value[_snapshotIndex.value];

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

/// Values that can be calculated from [CoreData] and notifiers that take signal
/// from widgets.
class DerivedData extends DisposableController with AutoDisposeControllerMixin {
  DerivedData(CoreData core) {
    this.selectedItem = ValueNotifier<SnapshotItem>(core.selectedItem);

    addAutoDisposeListener(
      singleClassStats,
      () => _setClassIfNotNull(singleClassStats.value?.heapClass, core),
    );
    addAutoDisposeListener(
      diffClassStats,
      () => _setClassIfNotNull(diffClassStats.value?.heapClass, core),
    );
    addAutoDisposeListener(
      pathEntry,
      () => _setPathIfNotNull(pathEntry.value?.key, core),
    );
  }

  /// Currently selected item, to take signal from the list widget.
  late final ValueNotifier<SnapshotItem> selectedItem;

  /// Classes to show.
  final heapClasses = ValueNotifier<HeapClasses?>(null);

  /// Selected single class item in snapshot, to take signal from the table widget.
  final singleClassStats = ValueNotifier<SingleClassStats?>(null);

  /// Selected diff class item in snapshot, to take signal from the table widget.
  final diffClassStats = ValueNotifier<DiffClassStats?>(null);

  /// List of retaining paths to show for the selected class.
  final pathEntries = ValueNotifier<List<StatsByPathEntry>?>(null);

  /// Selected retaining path record in a concrete snapshot, to take signal from the table widget.
  final pathEntry = ValueNotifier<StatsByPathEntry?>(null);

  final diffStore = HeapDiffStore();

  /// Updates cross-snapshot class if the argument is not null.
  void _setClassIfNotNull(HeapClassName? theClass, CoreData core) {
    if (theClass == null || theClass == core.className) return;
    core.className = theClass;
    _recalculateValues(core);
  }

  /// Updates cross-snapshot path if the argument is not null.
  void _setPathIfNotNull(ClassOnlyHeapPath? path, CoreData core) {
    if (path == null || path == core.path) return;
    core.path = path;
    _recalculateValues(core);
  }

  void _assertIntegrity() {
    assert(() {
      final singleClass = singleClassStats.value;
      final diffClass = diffClassStats.value;
      assert(singleClass == null || diffClass == null);
      return true;
    }());
  }

  /// List of classes to show for the selected snapshot.
  HeapClasses? _snapshotClasses(CoreData core) {
    final theItem = core.selectedItem;
    if (theItem is! SnapshotInstanceItem) return null;
    final heap = theItem.heap;
    if (heap == null) return null;
    final itemToDiffWith = theItem.diffWith.value;
    if (itemToDiffWith == null) return heap.classes;
    return diffStore.compare(heap, itemToDiffWith.heap!);
  }

  static void _updateClassStats({
    required HeapClasses? classes,
    required HeapClassName? className,
    required ValueNotifier<SingleClassStats?> singleToUpdate,
    required ValueNotifier<DiffClassStats?> diffToUpdate,
  }) {
    if (classes is SingleHeapClasses) {
      singleToUpdate.value = classes.classesByName[className];
      diffToUpdate.value = null;
    } else if (classes is DiffHeapClasses) {
      singleToUpdate.value = null;
      diffToUpdate.value = classes.classesByName[className];
    } else if (classes == null) {
      singleToUpdate.value = null;
      diffToUpdate.value = null;
    } else {
      throw StateError('Unexpected type: ${classes.runtimeType}.');
    }
  }

  /// Set [derived] values based on [core] values.
  ///
  /// It should be invoked after updating values in core, but not automatically
  /// on a single value change, but after an operation change.
  ///
  /// Operation here is an operation triggered by UI: selection change or change of data.
  void _recalculateValues(CoreData core) {
    // Set current snapshot.
    // derived._selectedItem.value = core.selectedItem;

    // Set classes to show.
    final classes = _snapshotClasses(core);
    heapClasses.value = classes;
    _updateClassStats(
      classes: classes,
      className: core.className,
      singleToUpdate: singleClassStats,
      diffToUpdate: diffClassStats,
    );

    // Set pathes to show.
    final theClass = singleClassStats.value ?? diffClassStats.value;
    final thePathEntries = pathEntries.value = theClass?.statsByPathEntries;
    final pathes = theClass?.statsByPath;
    StatsByPathEntry? byPathEntry;
    if (core.path != null && pathes != null && thePathEntries != null) {
      final pathStats = pathes[core.path];
      if (pathStats != null) {
        byPathEntry =
            thePathEntries.firstWhereOrNull((e) => e.key == core.path);
      }
    }
    pathEntry.value = byPathEntry;

    _assertIntegrity();
  }
}
