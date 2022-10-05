// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../../../../primitives/auto_dispose.dart';
import '../../../../../primitives/utils.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/heap/model.dart';
import 'heap_diff.dart';
import 'item_controller.dart';

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
  }

  /// Data that are necessary to calculate all other data.
  final core = CoreData();

  /// Data that can be calculated from [core].
  late final derived = DerivedData(core.selectedItem);

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
    final theItem = core.selectedItem;
    if (theItem is! SnapshotInstanceItem) return null;
    final heap = theItem.heap;
    if (heap == null) return null;
    final itemToDiffWith = theItem.diffWith.value;
    if (itemToDiffWith == null) return heap.classes;
    return derived.diffStore.compare(heap, itemToDiffWith.heap!);
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
  void _recalculateValues() {
    // Set current snapshot.
    // derived._selectedItem.value = core.selectedItem;

    // Set classes to show.
    final classes = _snapshotClasses();
    derived.heapClasses.value = classes;
    _updateClassStats(
      classes: classes,
      className: core.className,
      singleToUpdate: derived.singleClassStats,
      diffToUpdate: derived.diffClassStats,
    );

    // Set pathes to show.
    final theClass =
        derived.singleClassStats.value ?? derived.diffClassStats.value;
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
class DerivedData {
  DerivedData(SnapshotItem selectedItem) {
    this.selectedItem = ValueNotifier<SnapshotItem>(selectedItem);
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
}
